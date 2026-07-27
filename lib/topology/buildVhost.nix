# lib/topology/buildVhost.nix
# Shared vhost builder — extracted from modules/topology-derive.nix:135-276
# Used by genNginx.nix to produce topology-derived nginx vhost config.
#
# Produces vhost config from topology JSON vhost entries. All fields
# produced here are topology-derived (read from topology.vhosts, topology.coordinate,
# topology.acme_host, topology.default_response).
#
# Architecture boundary: this library handles ONLY topology-derived fields.
# The machine config provides additional overlay via NixOS module merging.
{ lib }:
{ topology }:
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
          let
            staticRoot = entry.static.root;
            absRoot =
              if hasPrefix "/" staticRoot then staticRoot
              else if hasSuffix "webroot" staticRoot then ../../webroot
              else ../../topology + ("/${staticRoot}");
          in
          {
            "/" = { root = absRoot; };
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
  enableNginx = vhostConfig != { } || defaultResponseConfig != { };

in
{
  inherit buildVhost vhostConfig defaultResponseConfig nginxVhosts enableNginx;
}
