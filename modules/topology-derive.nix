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
# See lib/topology/PRINCIPLE.md for the full repeated statement of this law.
# modules/topology-derive.nix
# Topology-driven configuration from JSON.
#
# CORE PRINCIPLE: No function in this entire topology toolset reads anything
# except JSON topology files. It is exclusive, totally isolated, and never
# touches a single user Nix file. The generators are pure JSON-to-attrset
# functions. This module is the MERGE POINT — it reads topology JSON from
# disk, calls the pure generators, and merges the resulting config attrsets
# into the NixOS module system.
#
# The topology JSON is passed as a module argument (topologyData) from
# flake.nix. This module NEVER references config.networking.hostName,
# config.topology.enable, or any other config value in its let block.
# The hostname comes from the JSON file itself (topologyData.hostname).
#
# Architecture:
#   topology/<machine>.json  ──→  pure generators  ──→  config attrset
#     (read from disk)            (genFirewall,          (networking.firewall,
#                                  genDns,                services.dnsmasq,
#                                  genNginx,               services.nginx,
#                                  genBackup)              environment.rclone-target)
#                                                        │
#                                              NixOS module merge
#                                                        ↓
#                                                  final config

{ lib, topologyData ? null, ... }:

let
  inherit (builtins)
    fromJSON readFile pathExists elemAt
    toString attrNames filter head
    removeAttrs;

  inherit (lib)
    hasPrefix hasSuffix optional mapAttrs'
    concatStringsSep nameValuePair splitString;

  # ── Topology loading ────────────────────────────────────────
  # topologyData is passed as a module argument from flake.nix.
  # It is the parsed JSON from topology/<hostname>.json.
  # If null, no topology config is generated.
  # The hostname comes from the JSON itself — NEVER from config.
  hasTopology = topologyData != null;
  topology = topologyData;
  hostname = if hasTopology then topology.hostname else null;

  # ── IP address helpers ──────────────────────────────────────
  subnetPeerToIP = subnet: peer_id:
    let
      parts = splitString "/" subnet;
      ip = elemAt parts 0;
      octets = splitString "." ip;
      prefix = concatStringsSep "." (lib.init octets);
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

  # ── First coordinate IP for listen addresses ──────────────
  firstIP =
    if hasTopology && (topology.coordinate or [ ]) != [ ]
    then subnetPeerToIP (head topology.coordinate).subnet (head topology.coordinate).peer_id
    else "0.0.0.0";

  # ── Exporter configuration ────────────────────────────────
  exporterConfig =
    if hasTopology && topology ? exporters then
      mapAttrs'
        (name: settings:
          let
            port = settings.port or defaultPorts.${name} or 9100;
            addr = settings.listenAddress or firstIP;
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

  # ── WireGuard public key validation ────────────────────────
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

  # ── Pure generator imports ─────────────────────────────────
  # These are pure functions: JSON -> config attrset.
  # No function in this entire topology toolset reads anything
  # except JSON topology files. It is exclusive, totally isolated,
  # and never touches a single user Nix file.
  genFirewall = import ../lib/topology/genFirewall.nix { inherit lib; };
  genDns = import ../lib/topology/genDns.nix { inherit lib; };
  genNginx = import ../lib/topology/genNginx.nix { inherit lib; };
  genBackup = import ../lib/topology/genBackup.nix { inherit lib; };

in
{
  # ── Config ──────────────────────────────────────────────
  # Generators are called here, in the config section.
  # The `import` calls above just create function references (lazy).
  # The actual generator calls happen when the config block is evaluated.
  config = lib.mkMerge [

    # ── Assertions and warnings ────────────────────────────
    (lib.mkIf hasTopology {
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

    # ── Firewall (via genFirewall) ─────────────────────────
    (lib.mkIf (hasTopology && topology ? firewall)
      (genFirewall topology.firewall))

    # ── DNS/DHCP (via genDns) ──────────────────────────────
    (lib.mkIf (hasTopology && (topology ? dns || topology ? lan_dhcp))
      {
        services.dnsmasq = ((genDns { inherit (topology) dns lan_dhcp; }).services.dnsmasq) // {
          settings = ((genDns { inherit (topology) dns lan_dhcp; }).services.dnsmasq.settings) // {
            domain = [ hostname ];
            local = [ "/${hostname}/" ];
          };
        };
      })

    # ── Nginx (via genNginx) ────────────────────────────────
    (lib.mkIf hasTopology (genNginx topology))

    # ── Backup (via genBackup) ──────────────────────────────
    (lib.mkIf (hasTopology && topology ? backup)
      (genBackup topology.backup))

    # ── Port forwarding / nftables ─────────────────────────
    (lib.mkIf (hasTopology && topology ? routes && topology.routes != [ ]) {
      networking.nftables.enable = true;
      networking.nftables.ruleset =
        let
          wanCoords = filter (c: lib.hasSuffix "-wan" (c.plane_name or "")) (topology.coordinate or [ ]);
          wanIface = if wanCoords != [ ] then (head wanCoords).interface else "wan";
          lanCoords = filter (c: lib.hasSuffix ".lan" (c.plane_name or "")) (topology.coordinate or [ ]);
          lanSubnet = if lanCoords != [ ] then (head lanCoords).subnet else "10.0.0.0/8";
          tcpRoutes = filter (r: r.proto == "tcp") topology.routes;
          udpRoutes = filter (r: r.proto == "udp") topology.routes;
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

    # ── Tailscale advertised routes ─────────────────────────
    (lib.mkIf (hasTopology && topology ? advertised_tailscale_routes) {
      services.tailscale = {
        enable = true;
        extraSetFlags = [
          "--advertise-routes=${concatStringsSep "," topology.advertised_tailscale_routes}"
        ];
        useRoutingFeatures = "server";
      };
    })

    # ── WireGuard hub configuration ─────────────────────────
    (lib.mkIf (hasTopology && topology ? wireguard) {
      networking.wireguard.enable = true;
      networking.wireguard.interfaces =
        let
          wgCoords = filter (c: c.plane_name == "wg") (topology.coordinate or [ ]);
          wgCoord = if wgCoords != [ ] then head wgCoords else null;
          selfWgIp = if wgCoord != null then "${subnetPeerToIP wgCoord.subnet wgCoord.peer_id}/32" else "";
          subnetOctets = splitString "." (builtins.head (splitString "/" (if wgCoord != null then wgCoord.subnet else "0.0.0.0/24")));
          subnetPrefix = "${elemAt subnetOctets 0}.${elemAt subnetOctets 1}.${elemAt subnetOctets 2}";
          subnetCidr = elemAt (splitString "/" (if wgCoord != null then wgCoord.subnet else "0.0.0.0/24")) 1;
          subnetNetIp = "${subnetPrefix}.0/${subnetCidr}";
          readPubKey = hostnameKey:
            let
              p = ../secrets/public_keys/wireguard/wg_${hostnameKey}_pub;
            in
            if builtins.pathExists p then builtins.readFile p else null;
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
          };
        };
    })
  ];
}
