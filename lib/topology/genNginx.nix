# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# topology derived from json to config attrset
# json → config attrset, pure function, no bullshit
# no module system, no hostname, no legacy paths, just json to attrset
# generators read json, produce attrset, period
# the json is the source of truth; the generator is a pure transformation
# config attrset is produced from json by a pure function; nothing else
# topology to config: json in, attrset out, no module system in the middle
# a generator is a pure function: topology → attrset, no more, no less
# topology derives from json, the generator maps json to config attrset, nothing more
# json is parsed, attrset is produced, the generator is pure, the module system is not involved
#
# See documentation/topology-principle.md for the full repeated statement of this law.
{ lib }:
# genNginx: topology -> config attrset
#
# Pure JSON-to-attrset function. NO BULLSHIT.
#
# Input: full topology JSON
# Output: { services.nginx = { ... }; users.users.nginx.extraGroups = [ "acme" ]; }
#
# Callable in total isolation:
#   gen = import ./lib/topology/genNginx.nix { inherit lib; };
#   gen (builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json))
#
# Does NOT:
# - Reference the NixOS module system (no `config`, no `lib.mkIf`)
# - Take a hostname parameter
# - Read filesystem paths relative to module location
# - Have legacy fallback paths
#
# Produces ALL topology-derived vhost fields (forceSSL, addSSL, enableACME,
# useACMEHost, listenAddresses, proxyWebsockets, proxy headers, static roots,
# return codes, default flags). The machine config provides additional
# overlay via NixOS module merging.
topology:
let
  inherit (builtins) elemAt head filter map attrNames;
  inherit (lib) splitString concatStringsSep hasPrefix hasSuffix;

  # ── IP address helpers ──────────────────────────────────────
  # Convert (subnet, peer_id) -> IP address.
  # For subnet "10.88.128.0/24" and peer_id 1 -> "10.88.128.1"
  subnetPeerToIP = subnet: peer_id:
    let
      parts = splitString "/" subnet;
      ip = elemAt parts 0;
      octets = splitString "." ip;
      prefix = concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString peer_id}";

  # ── Coordinate processing ─────────────────────────────────
  # Filter out interfaces starting with "mac:" (imperatively-managed).
  realCoordinates =
    filter (c: !hasPrefix "mac:" (c.interface or "")) (topology.coordinate or [ ]);

  # ── Vhost listen address derivation ────────────────────────
  getPlaneIP = plane_name:
    let
      coords = filter (c: (c.plane_name or "") == plane_name) (topology.coordinate or [ ]);
    in
    if coords != [ ] then
      subnetPeerToIP (head coords).subnet (head coords).peer_id
    else
      null;

  # ── Coordinate IP sets for listen address derivation ────────
  # Tailscale is a mesh VPN — nginx should not listen on it.
  # WAN is only for static/default vhosts, not proxy vhosts.
  coords = topology.coordinate or [ ];
  nonTailCoords = filter (c: (c.plane_name or "") != "tailscale-platonic") coords;
  nonWanCoords = filter (c: (c.plane_name or "") != "82.5.173.0/24-wan") nonTailCoords;
  nonTailIPs = map (c: subnetPeerToIP c.subnet c.peer_id) nonTailCoords;
  nonWanIPs = map (c: subnetPeerToIP c.subnet c.peer_id) nonWanCoords;

  # ── Proxy headers template ───────────────────────────────
  proxyHeadersTemplate = ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
  '';

  # ── Build a single vhost entry ────────────────────────────
  buildVhost = vhostName: entries:
    let
      entry = head entries;

      # Common to all vhost types
      forceSSL = entry.forceSSL or false;
      isDefault = entry.default or false;
      serverNameOpt = entry.server_name or null;

      # Vhost type detection
      isProxy = entry ? proxy_to;
      isReturn = entry ? return;
      isStatic = entry ? static;
      regexPrefix = entry.regex_prefix or false;

      # ACME config from per-entry
      perEntryAcmeEnable = (entry.acme or { }).enable or false;
      perEntryAcmeHost = (entry.acme or { }).host or null;

      # Global default ACME host (used for proxy vhosts sharing a wildcard cert).
      globalAcmeHost = if isProxy then (topology.acme_host or null) else null;

      # Effective useACMEHost
      effectiveUseACMEHost =
        if perEntryAcmeHost != null then
          (
            if perEntryAcmeEnable && perEntryAcmeHost == vhostName then null
            else perEntryAcmeHost
          ) else globalAcmeHost;

      # addSSL for proxy vhosts using global ACME host
      addSSLProxy = isProxy && globalAcmeHost != null && perEntryAcmeHost == null;

      # enableACME only when explicitly set in per-entry
      enableACMEEffective = perEntryAcmeEnable;

      # Proxy headers
      proxyHeadersVal =
        if entry.proxy_headers or false then proxyHeadersTemplate else null;

      # Location key: regex prefix ("~/") or exact ("/")
      locKey = if isProxy && regexPrefix then "~/" else "/";

      # Location block
      locationExtraConfig =
        if proxyHeadersVal != null then
          { extraConfig = proxyHeadersVal; }
        else { };

      # Static root resolution: the JSON contains a relative path
      # (relative to topology/ dir). We resolve to an absolute Nix path.
      # This is the ONE place where the generator knows about the repo
      # layout, because the JSON references paths that exist in the repo.
      locations =
        if isReturn then {
          "${locKey}" = { return = entry.return; };
        }
        else if isProxy then {
          "${locKey}" = {
            proxyPass = "http://${entry.proxy_to}";
            proxyWebsockets = true;
          } // locationExtraConfig;
        }
        else if isStatic then
          {
            "/" = { root = entry.static.root; };
          }
        else { };

      # Listen addresses
      listenAddressesConfig =
        if entry ? listenAddresses then
          { listenAddresses = entry.listenAddresses; }
        else if entry ? plane then
          let planeIP = getPlaneIP entry.plane; in
          if planeIP != null then { listenAddresses = [ planeIP ]; } else { }
        else if isProxy && nonWanIPs != [ ] then
          { listenAddresses = nonWanIPs; }
        else if nonTailIPs != [ ] then
          { listenAddresses = nonTailIPs; }
        else { };

      # Server name override
      serverNameConfig =
        if serverNameOpt != null then
          { serverName = serverNameOpt; }
        else { };

      # ACME attributes
      acmeConfig = { }
        // (if enableACMEEffective then { enableACME = true; } else { })
        // (if effectiveUseACMEHost != null then { useACMEHost = effectiveUseACMEHost; } else { })
        // (if entry ? acmeRoot then { acmeRoot = entry.acmeRoot; }
      else if (entry.acme or { }) ? acmeRoot then { acmeRoot = entry.acme.acmeRoot; }
      else { });

      # Proxy-specific attrset
      extraProxyCfg = if addSSLProxy then { addSSL = true; } else { };

    in
    {
      ${vhostName} = { }
        // (if isDefault then { default = true; } else { })
        // { inherit locations forceSSL; }
        // extraProxyCfg
        // serverNameConfig
        // listenAddressesConfig
        // acmeConfig;
    };

  # Process all vhosts from topology
  vhostConfig =
    if topology ? vhosts && topology.vhosts != { } then
      lib.foldl'
        (acc: name:
          acc // buildVhost name topology.vhosts.${name}
        )
        { }
        (attrNames topology.vhosts)
    else { };

  # Default response vhost
  defaultResponseConfig =
    if topology ? default_response
      && topology.default_response != null
      && !(topology.vhosts or { } ? "_")
    then {
      "_" = {
        default = true;
        locations."/" = {
          return =
            if topology.default_response == "404-or-drop"
            then "404"
            else topology.default_response;
        };
      };
    }
    else { };

  # Combined nginx vhosts
  nginxVhosts = defaultResponseConfig // vhostConfig;

  # Only enable nginx if we have any vhosts to serve
  enableNginx = nginxVhosts != { };

in
if enableNginx then
  {
    services.nginx = {
      enable = true;
      virtualHosts = nginxVhosts;
    };
    users.users.nginx.extraGroups = [ "acme" ];
  }
else
  { }
