# modules/topology-derive.nix
# Phase 5-1.3.1: Foundation module that reads JSON topology and derives NixOS config.
#
# Reads topology/<hostname>.json and derives:
#   - networking.interfaces.*.ipv4.addresses  (from coordinate entries)
#   - services.prometheus.exporters.*         (from exporters map)
#   - services.nginx.virtualHosts.*           (from vhosts map + default_response)
#
# Design principles:
#   - Uses normal Nix merging ONLY (NO mkForce/mkOverride).
#   - Lists concatenate, attrsets merge recursively.
#   - If no JSON file exists for this hostname -> produces no config (early return).
#   - Interfaces starting with "mac:" are skipped (imperatively-managed devices).
#   - Registry validation surfaces errors as build assertions.
#
# { config, lib, pkgs, self, ... }:
#   ^ self is accepted for WireGuard path resolution (dormant), not required for JSON paths.

{ config, lib, pkgs, self, ... }:

let
  inherit (builtins)
    fromJSON readFile pathExists elemAt
    toString attrNames filter head
    removeAttrs;

  inherit (lib)
    hasPrefix hasSuffix optional mapAttrs'
    concatStringsSep nameValuePair splitString;

  # Read the hostname from the NixOS config (already set by hardware/user config).
  # The hostname MUST match the topology filename -- enforced by mkRegistry.nix
  # validator 1 (filename/hostname binding).
  hostname = config.networking.hostName;
  topologyFile = ../topology/${hostname}.json;
  hasTopology = pathExists topologyFile;
  topology = if hasTopology then fromJSON (readFile topologyFile) else null;

  # ── IP address helpers ──────────────────────────────────────

  # Convert (subnet, peer_id) -> IP address.
  # For subnet "10.88.128.0/24" and peer_id 1 -> "10.88.128.1"
  subnetPeerToIP = subnet: peer_id:
    let
      parts = splitString "/" subnet;
      ip = elemAt parts 0; # "10.88.128.0"
      octets = splitString "." ip;
      prefix = concatStringsSep "." (lib.init octets); # "10.88.128"
    in
    "${prefix}.${toString peer_id}";

  # ── Default exporter ports ────────────────────────────────
  defaultPorts = {
    node = 9100;
    nvidia = 9101;
    disk = 9102;
    smartctl = 9633;
    dnsmasq = 3101;
    nextcloud = 3106;
    nginx = 9113;
  };

  # ── Cross-machine registry validation ──────────────────────
  registry = import ../lib/topology/mkRegistry.nix { inherit lib; };
  registryErrors = registry.errors;
  registryWarnings = registry.warnings;

  # ── Coordinate processing ─────────────────────────────────
  # Filter out interfaces starting with "mac:" (imperatively-managed).
  realCoordinates =
    if hasTopology then
      filter (c: !hasPrefix "mac:" (c.interface or "")) (topology.coordinate or [ ])
    else [ ];

  # ── First coordinate IP for listen addresses ──────────────
  firstIP =
    if realCoordinates != [ ]
    then subnetPeerToIP (head realCoordinates).subnet (head realCoordinates).peer_id
    else "0.0.0.0";

  # ── Vhost listen address derivation ────────────────────────
  # When a vhost entry has no explicit listenAddresses, derive them
  # from coordinates. If the entry has a "plane" field, use only the
  # coordinate matching that plane. Otherwise use all coordinates.
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

  # ── Exporter configuration ────────────────────────────────
  # Each exporter entry in topology.exporters becomes:
  #   services.prometheus.exporters.<name>
  #     = { enable = true; port = ...; listenAddress = ...; extra... }
  #
  # Supports per-entry overrides:
  #   - port: override the default port
  #   - listenAddress: override the default firstIP listen address
  #   - any other fields passed through as-is (e.g. leasesPath, dnsmasqListenAddress)
  exporterConfig =
    if hasTopology && topology ? exporters then
      mapAttrs'
        (name: settings:
          let
            port = settings.port or defaultPorts.${name} or 9100;
            addr = settings.listenAddress or firstIP;
            # Pass through all other exporter-specific options unchanged
            extra = removeAttrs settings [ "port" "listenAddress" ];
          in
          nameValuePair name ({
            enable = true;
            inherit port;
            listenAddress = addr;
          } // extra)
        )
        topology.exporters
    else { };

  # ── Nginx virtual host configuration ─────────────────────

  # Build a single vhost entry from its (name, [entry]) pair.
  # Each vhost entry is a list; take the first element (Phase B).
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
      # Location key: "~/" (regex prefix) when regex_prefix is true, "/" (exact) otherwise
      regexPrefix = entry.regex_prefix or false;

      # ACME config from per-entry
      perEntryAcmeEnable = (entry.acme or { }).enable or false;
      perEntryAcmeHost = (entry.acme or { }).host or null;

      # Global default ACME host (used for proxy vhosts sharing a wildcard cert).
      # Only applies to PROXY vhosts, not return/static vhosts.
      globalAcmeHost = if isProxy then (topology.acme_host or null) else null;

      # Effective useACMEHost:
      #   - If per-entry acme.host is set AND differs from vhost name, OR
      #     per-entry acme.host is set AND enableACME is NOT true (reference),
      #     use per-entry value.
      #   - If per-entry acme.host is set AND equals vhost name AND
      #     enableACME is true (self-managed cert), don't set useACMEHost.
      #   - If no per-entry acme and vhost is a proxy, use global acme_host.
      effectiveUseACMEHost =
        if perEntryAcmeHost != null then
          (
            if perEntryAcmeEnable && perEntryAcmeHost == vhostName then null
            else perEntryAcmeHost
          ) else globalAcmeHost;

      # addSSL for proxy vhosts using global ACME host (matching genNginx).
      # Per-entry acme.host does NOT auto-set addSSL (matches golden/baseline).
      addSSLProxy = isProxy && globalAcmeHost != null && perEntryAcmeHost == null;

      # enableACME only when explicitly set in per-entry
      enableACMEEffective = perEntryAcmeEnable;

      # Proxy headers — enabled by per-entry proxy_headers flag.
      # When true, adds standard reverse-proxy headers to the location.
      # The golden for some machines (e.g. cortex-alpha) expects these
      # per-location headers from the old genNginx generator.
      proxyHeadersVal =
        if entry.proxy_headers or false then ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
        '' else null;

      # Location key: regex prefix ("~/") or exact ("/")
      locKey = if isProxy && regexPrefix then "~/" else "/";

      # Location block -- varies by type
      locationExtraConfig =
        if proxyHeadersVal != null then
          { extraConfig = proxyHeadersVal; }
        else { };

      locations =
        # Return-type vhost (e.g., catch-all return "444")
        if isReturn then {
          "${locKey}" = { return = entry.return; };
        }
        # Proxy-type vhost: with proxyWebsockets, optional extraConfig, proxy_pass
        else if isProxy then {
          "${locKey}" = {
            proxyPass = "http://${entry.proxy_to}";
            proxyWebsockets = true;
          } // locationExtraConfig;
        }
        # Static-type vhost (e.g., serve files from a root)
        # Resolve relative root paths (from JSON, relative to topology/ dir)
        # to absolute Nix paths so the serializer produces <path> not <eval-error>.
        # Formula: ./../topology + "/" + staticRoot = absolute path from module dir
        else if isStatic then
          let
            staticRoot = entry.static.root;
            # JSON paths are relative to topology/. Prefer known in-repo roots.
            # Avoid path arithmetic that escapes into /nix/store/webroot under pure eval.
            absRoot =
              if hasPrefix "/" staticRoot then staticRoot
              else if hasSuffix "webroot" staticRoot then ../webroot
              else ../topology + ("/${staticRoot}");
          in
          {
            "/" = { root = absRoot; };
          }
        else { };

      # Listen addresses: explicit override, plane-derivation, or full-derivation
      # Proxy vhosts: LAN + WG only (no tailscale, no WAN)
      # Static/default vhosts: LAN + WG + WAN (no tailscale)
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

      # Server name override (when vhost key differs from server_name)
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

      # Proxy-specific attrset (addSSL when using global ACME host)
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

  # Process all vhosts from topology into a flat attrset of vhost configs.
  vhostConfig =
    if hasTopology && topology ? vhosts && topology.vhosts != { } then
      lib.foldl'
        (acc: name:
          acc // buildVhost name topology.vhosts.${name}
        )
        { }
        (attrNames topology.vhosts)
    else { };

  # Default response vhost (from top-level default_response field).
  # Only applies when there is NO explicit "_" vhost in vhosts,
  # to avoid conflicting return values.
  # Maps "404-or-drop" -> nginx return code "404".
  defaultResponseConfig =
    if hasTopology
      && topology ? default_response
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

  # Combined nginx vhosts: default_response first, explicit vhosts override.
  nginxVhosts = defaultResponseConfig // vhostConfig;

  # Only enable nginx if we have any vhosts to serve.
  enableNginx = vhostConfig != { } || defaultResponseConfig != { };

  # ── WireGuard public key validation (dormant) ────────────
  # Reads the public_key_file path from topology and emits a warning
  # if the file is missing. Path is relative to repo root.
  pubkeyWarnings =
    if hasTopology && topology ? public_key_file then
      let
        pkf = topology.public_key_file;
        fullPath = ../${pkf};
        exists = pathExists fullPath;
      in
      optional (!exists)
        "Topology: public_key_file '${pkf}' not found at ${toString fullPath}"
    else [ ];

in
{
  # ── Options ──────────────────────────────────────────────
  options.topology.enable = lib.mkOption {
    type = lib.types.bool;
    default = hasTopology;
    defaultText = lib.literalExpression "hasTopology";
    description = ''
      Enable topology-derived configuration for this host.
      Defaults to true when topology/${hostname}.json exists.
      Set to false to disable topology config without deleting the JSON file.
    '';
  };

  # ── Config ──────────────────────────────────────────────
  # Split into motion pieces so nested mkIf cannot stub users.users.nginx
  # on hosts without nginx (would trip isSystemUser assertions).
  config = lib.mkMerge [

    (lib.mkIf (hasTopology && config.topology.enable) {
      assertions = [
        {
          assertion = registryErrors == [ ];
          message = ''
            Topology validation errors for ${hostname}:
            ${concatStringsSep "\n  " registryErrors}
          '';
        }
      ];
      warnings = registryWarnings ++ pubkeyWarnings;
      services.prometheus.exporters = exporterConfig;
    })

    (lib.mkIf (hasTopology && config.topology.enable && enableNginx) {
      services.nginx = {
        enable = true;
        virtualHosts = nginxVhosts;
      };
      users.users.nginx.extraGroups = [ "acme" ];
    })

    # ── Firewall (Phase M-2.1) ──────────────────────────────────
    (lib.mkIf (hasTopology && config.topology.enable && topology ? firewall) {
      networking.firewall = {
        allowedTCPPorts = topology.firewall.allowed_tcp_ports or [ ];
        allowedUDPPorts = topology.firewall.allowed_udp_ports or [ ];
        interfaces = lib.mapAttrs
          (_iface: rules: {
            allowedTCPPorts = rules.tcp or [ ];
            allowedUDPPorts = rules.udp or [ ];
          })
          (topology.firewall.interfaces or { });
      };
    })

    # ── DNS/DHCP (Phase M-2.2) ──────────────────────────────────
    (lib.mkIf (hasTopology && config.topology.enable && (topology ? dns || topology ? lan_dhcp)) {
      services.dnsmasq = {
        enable = true;
        settings = {
          interface = [ (topology.dns.interface or topology.lan_dhcp.interface or "") ];
          # dhcp-range with interface prefix (matching mkDhcpDns.nix format)
          "dhcp-range" =
            let
              dhcpIface = topology.lan_dhcp.interface or topology.dns.dhcp.interface or topology.dns.interface or "";
              dhcpRange = topology.lan_dhcp.range or topology.dns.dhcp.range or "";
            in
            [ "${dhcpIface},${dhcpRange}" ];
          address = map (entry: "/${entry.domain}/${entry.ip}") (topology.dns.static or [ ]);
          server = topology.dns.servers or [ ];
          # DHCP static hosts (from lan_dhcp.hosts — matching mkDhcpDns.nix)
          dhcp-host = builtins.sort (a: b: a < b) (
            map (h: "${h.mac},${h.ip},${h.hostname},infinite")
              (topology.lan_dhcp.hosts or topology.dns.dhcp.hosts or [ ])
          );
          # Additional dnsmasq settings (matching mkDhcpDns.nix)
          domain = [ hostname ];
          local = [ "/${hostname}/" ];
          domain-needed = true;
          bogus-priv = true;
          no-resolv = true;
          cache-size = 1000;
        };
      };
    })

    # ── Port forwarding / nftables (Phase M-2.3) ────────────────
    (lib.mkIf (hasTopology && config.topology.enable && topology ? routes && topology.routes != [ ]) {
      networking.nftables.enable = true;
      networking.nftables.ruleset =
        let
          # Derive WAN interface from coordinate whose plane_name contains "-wan"
          wanCoords = filter (c: lib.hasSuffix "-wan" (c.plane_name or "")) (topology.coordinate or [ ]);
          wanIface = if wanCoords != [ ] then (head wanCoords).interface else "wan";
          # Derive LAN subnet from coordinate whose plane_name contains ".lan"
          lanCoords = filter (c: lib.hasSuffix ".lan" (c.plane_name or "")) (topology.coordinate or [ ]);
          lanSubnet = if lanCoords != [ ] then (head lanCoords).subnet else "10.0.0.0/8";
          # Partition routes by protocol
          tcpRoutes = filter (r: r.proto == "tcp") topology.routes;
          udpRoutes = filter (r: r.proto == "udp") topology.routes;
          # Generate a DNAT rule string
          mkDnat = proto: route:
            "      iifname \"${wanIface}\" ${proto} dport ${toString route.port} dnat to ${route.to}";
          tcpRules = map (mkDnat "tcp") tcpRoutes;
          udpRules = map (mkDnat "udp") udpRoutes;
          allRules = concatStringsSep "\n" (tcpRules ++ udpRules);
        in
        ''
          table ip nat {
            chain prerouting {
              type nat hook prerouting priority dstnat; policy accept;
          ${allRules}
            };
            chain postrouting {
              type nat hook postrouting priority srcnat; policy accept;
              oifname "${wanIface}" ip saddr ${lanSubnet} masquerade
            };
          }
        '';
    })

    # ── Tailscale advertised routes (Phase M-2.4) ────────────────
    (lib.mkIf (hasTopology && config.topology.enable && topology ? advertised_tailscale_routes) {
      services.tailscale = {
        enable = true;
        extraSetFlags = [
          "--advertise-routes=${concatStringsSep "," topology.advertised_tailscale_routes}"
        ];
        useRoutingFeatures = "server";
      };
    })

    # ── WireGuard hub configuration (Phase M-2 supplement) ──────
    # Derives WireGuard peers from the JSON registry (all hosts with
    # a "wg" coordinate) and reads their public keys from secret files.
    (lib.mkIf (hasTopology && config.topology.enable && topology ? wireguard) {
      networking.wireguard.enable = true;
      networking.wireguard.interfaces =
        let
          # Derive WG IP from WG coordinate
          wgCoords = filter (c: c.plane_name == "wg") (topology.coordinate or [ ]);
          wgCoord = if wgCoords != [ ] then head wgCoords else null;
          selfWgIp = if wgCoord != null then "${subnetPeerToIP wgCoord.subnet wgCoord.peer_id}/32" else "";
          # Subnet IP (network address for the WG subnet)
          subnetOctets = splitString "." (builtins.head (splitString "/" (if wgCoord != null then wgCoord.subnet else "0.0.0.0/24")));
          subnetPrefix = "${elemAt subnetOctets 0}.${elemAt subnetOctets 1}.${elemAt subnetOctets 2}";
          subnetCidr = elemAt (splitString "/" (if wgCoord != null then wgCoord.subnet else "0.0.0.0/24")) 1;
          subnetNetIp = "${subnetPrefix}.0/${subnetCidr}";
          # Read public key from secrets file
          readPubKey = hostnameKey:
            let
              p = ../secrets/public_keys/wireguard/wg_${hostnameKey}_pub;
            in
            if builtins.pathExists p then builtins.readFile p else null;
          # Build peers from registry (all hosts with WG coordinate except self)
          allHostnames = builtins.attrNames registry.hosts;
          peerList =
            if wgCoord == null then [ ] else
            lib.flatten (map
              (name:
                if name == hostname then [ ] else
                let
                  peerHost = registry.hosts.${name};
                  peerWgCoords = filter (c: c.plane_name == "wg") (peerHost.coordinate or [ ]);
                  peerCoord = if peerWgCoords != [ ] then head peerWgCoords else null;
                  pubKey = readPubKey name;
                in
                if peerCoord == null || pubKey == null then [ ] else [{
                  publicKey = pubKey;
                  allowedIPs = [ "${subnetPeerToIP peerCoord.subnet peerCoord.peer_id}/32" ];
                }]
              )
              allHostnames);
        in
        {
          ${topology.wireguard.interface} = {
            ips = [ selfWgIp subnetNetIp ];
            listenPort = topology.wireguard.listen_port;
            peers = peerList;
            # privateKeyFile is set by machine config (cortex-alpha/default.nix)
          };
        };
    })

  ]; # config merge
}
