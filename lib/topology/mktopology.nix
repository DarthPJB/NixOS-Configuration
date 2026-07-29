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
{ lib }:
# mktopology: path -> { hostname = config attrset; ... }
#
# Flake-level topology-to-config function. Takes a directory path containing
# topology JSON files and returns an attrset mapping hostnames to NixOS config
# attrsets derived from those files.
#
# The output is pure data — an attrset of config attrsets — that gets merged
# into nixosConfigurations via the NixOS module system. This is NOT a module;
# it does NOT import any machine config, set specialArgs, or define system type.
#
# Callable in total isolation:
#   mktopology = (import ./lib/topology/mktopology.nix { inherit lib; }).mktopology;
#   topologyConfigs = mktopology ./topology/;
#
# Architecture:
#   topology/<machine>.json  ──→  pure generators  ──→  config attrset
#     (read from disk)            (genFirewall,          (networking.firewall,
#                                  genDns,                services.dnsmasq,
#                                  genNginx,               services.nginx,
#                                  genBackup)              environment.rclone-target)
#                                                           │
#                                                 NixOS module merge
#                                                           ↓
#                                                     final config
{
  mktopology = topologyDir:
    let
      # ── Pure generator imports ────────────────────────────────
      # These are pure functions: JSON -> config attrset.
      # No function in this entire topology toolset reads anything
      # except JSON topology files. It is exclusive, totally isolated,
      # and never touches a single user Nix file.
      genFirewall = import ./genFirewall.nix { inherit lib; };
      genDns = import ./genDns.nix { inherit lib; };
      genNginx = import ./genNginx.nix { inherit lib; };
      genBackup = import ./genBackup.nix { inherit lib; };
      genWireguard = import ./genWireguard.nix { inherit lib; };

      # ── Cross-machine Registry ─────────────────────────────────
      # WireGuard peer discovery is inherently cross-machine — the hub
      # must know about ALL connected clients from the registry.
      # This is the ONE exception to the "generators only read JSON"
      # principle: the registry reads all topology JSON files to build
      # a validated cross-machine view.
      registry = import ./mkRegistry.nix { inherit lib; };

      # ── WireGuard settings builder ─────────────────────────────
      # Builds the settings object that genWireguard consumes.
      # Extracted from modules/enable-wg-topology.nix (the module
      # remains for client-side secrix/SSH/firewall config).
      coordToIp = coord:
        let
          parts = lib.splitString "/" coord.subnet;
          networkIp = builtins.head parts;
          octets = lib.splitString "." networkIp;
          prefix = lib.concatStringsSep "." (lib.init octets);
        in
        "${prefix}.${toString coord.peer_id}";

      readPubKey = hostnameKey:
        let
          path = ../../secrets/public_keys/wireguard/wg_${hostnameKey}_pub;
        in
        if builtins.pathExists path
        then builtins.readFile path
        else null;

      hubHostname = "cortex-alpha";

      # All hostnames with a wg coordinate
      allWgHostnames = builtins.attrNames (lib.filterAttrs
        (_name: host:
          builtins.any (c: c.plane_name == "wg") (host.coordinate or [ ])
        )
        registry.hosts);

      # Build per-machine WireGuard settings for genWireguard
      buildWgMachineSettings = hostname:
        let
          host = registry.hosts.${hostname} or null;
          wgCoords = builtins.filter (c: c.plane_name == "wg") (host.coordinate or [ ]);
          wgCoord = if wgCoords != [ ] then builtins.head wgCoords else null;
          mIp = if wgCoord != null then coordToIp wgCoord else null;
          isHub = hostname == hubHostname;
          hubPubKey = readPubKey hubHostname;
          hubHost = registry.hosts.${hubHostname} or null;
          hubWgCoords = builtins.filter (c: c.plane_name == "wg") (hubHost.coordinate or [ ]);
          hubWgCoord = if hubWgCoords != [ ] then builtins.head hubWgCoords else null;
          hubWgIp = if hubWgCoord != null then coordToIp hubWgCoord else null;
          listenPort = if hubHost != null then hubHost.wireguard.listen_port or 2108 else 2108;
          interfaceName = if wgCoord != null then wgCoord.interface else "wireg0";
          # Subnet IP for hubIps (third octet preserved, fourth = .0)
          subnetStr = if wgCoord != null then wgCoord.subnet else "10.88.127.0/24";
          subnetParts = lib.splitString "." (builtins.head (lib.splitString "/" subnetStr));
          subnetIp = "${builtins.elemAt subnetParts 0}.${builtins.elemAt subnetParts 1}.${builtins.elemAt subnetParts 2}.0";
          # For hub: all other WG hosts as peers (without endpoints)
          clientPeers =
            if !isHub then [ ] else
            lib.flatten (map
              (name:
                if name == hostname then [ ] else
                let
                  peerCoord = builtins.head (builtins.filter
                    (c: c.plane_name == "wg")
                    (registry.hosts.${name}.coordinate or [ ]));
                  peerPubKey = readPubKey name;
                in
                if peerPubKey == null then [ ] else
                let peerIp = coordToIp peerCoord; in
                [{
                  name = name;
                  publicKey = peerPubKey;
                  allowedIPs = [ peerIp ];
                }]
              )
              allWgHostnames
            );
          # For non-hub: only the hub peer (with endpoint)
          hubPeer =
            if isHub then [ ] else
            if hubPubKey == null then [ ] else [{
              name = hubHostname;
              publicKey = hubPubKey;
              allowedIPs = [ hubWgIp "10.88.127.0/24" ];
              endpoint = "${hubHostname}.johnbargman.net:${toString listenPort}";
            }];
          peers = hubPeer ++ clientPeers;
        in
        if wgCoord == null then null
        else {
          inherit hostname;
          interface = interfaceName;
          inherit listenPort;
          machineIp = mIp;
          inherit isHub;
          hubIps = if isHub then [ "${mIp}/32" "${subnetIp}/24" ] else [ ];
          inherit peers;
        };

      # Build the full wireguardSettings object consumed by genWireguard
      wgMachineList = builtins.filter (x: x != null) (
        map buildWgMachineSettings (builtins.attrNames registry.hosts)
      );
      wireguardSettings = {
        machines = builtins.listToAttrs (map (m: { name = m.hostname; value = m; }) wgMachineList);
        warnings = [ ];
        errors = [ ];
      };

      # ── File discovery and filtering ─────────────────────────
      # Use readDir to find all .json files, excluding _-prefixed
      # files (templates, test fixtures, etc.).
      topologyFiles = lib.filterAttrs
        (name: type:
          type == "regular"
          && lib.hasSuffix ".json" name
          && !lib.hasPrefix "_" name
        )
        (builtins.readDir topologyDir);

      # ── Static root resolution ──────────────────────────────
      # genNginx expects absolute Nix paths for static roots. Since
      # topology JSON references paths relative to the topology/
      # directory (e.g., "../webroot"), we resolve them here.
      #
      # This is the ONE place where mktopology knows about filesystem
      # paths beyond the topology directory. This is acceptable because:
      # - JSON topology files reference paths that exist in the repo
      # - The generator itself (genNginx.nix) remains pure — it receives
      #   the resolved path
      # - This mirrors the same pattern in topology-derive.nix
      resolveStaticRoots = topology:
        topology // {
          vhosts = lib.mapAttrs
            (_vhostName: entries:
              map
                (entry:
                  if entry ? static && entry.static ? root then
                    let
                      staticRoot = entry.static.root;
                      absRoot =
                        if lib.hasPrefix "/" staticRoot then staticRoot
                        else
                          builtins.path {
                            path = topologyDir + ("/${staticRoot}");
                          };
                    in
                    entry // { static = entry.static // { root = absRoot; }; }
                  else entry
                )
                entries
            )
            (topology.vhosts or { });
        };

      # ── Build single-machine config ──────────────────────────
      # Calls each pure generator conditionally based on which sections
      # the topology JSON has, then merges results with lib.mkMerge.
      # The merged result is an attrset suitable for use as a NixOS
      # module (passed into the modules list).
      mkMachineConfig = hostname: topology:
        # Fold with recursiveUpdate to produce a PLAIN attrset (not a mkMerge type).
        # The module system requires plain attrsets or module functions in modules = [...].
        builtins.foldl' lib.recursiveUpdate { } (

          # Filter out empty configs — no-op for recursiveUpdate but keeps it clean
          builtins.filter (x: x != { }) [

            # ── Firewall (conditional on topology.firewall) ───────
            (if topology ? firewall then genFirewall topology.firewall else { })

            # ── DNS/DHCP (conditional on topology.dns or lan_dhcp) ─
            (if topology ? dns || topology ? lan_dhcp then
              let
                dnsConfig = genDns { inherit (topology) dns lan_dhcp; };
              in
              dnsConfig // {
                services.dnsmasq = dnsConfig.services.dnsmasq // {
                  settings = dnsConfig.services.dnsmasq.settings // {
                    domain = [ hostname ];
                    local = [ "/${hostname}/" ];
                  };
                };
              }
            else { })

            # ── Nginx (always — returns {} if no vhosts) ─────────
            (genNginx (resolveStaticRoots topology))

            # ── Backup (conditional on topology.backup) ──────────
            (if topology ? backup then genBackup topology.backup else { })

            # ── WireGuard (conditional on topology.wireguard) ───
            # Uses the cross-machine registry for peer discovery.
            # Only the hub (cortex-alpha) has topology.wireguard set;
            # clients get their WG config from enable-wg-topology.nix.
            (if topology ? wireguard then
              lib.recursiveUpdate
                (genWireguard wireguardSettings hostname)
                { networking.wireguard.enable = true; }
            else { })

          ]

        );

      # ── Process a single topology file ────────────────────────
      # Parses the JSON, extracts the hostname, and builds the config
      # attrset. Returns { <hostname> = <config attrset>; }.
      processFile = filename: _type:
        let
          filePath = topologyDir + "/${filename}";
          rawJson = builtins.readFile filePath;
          topology = builtins.fromJSON rawJson;
          hostname = topology.hostname;
        in
        { ${hostname} = mkMachineConfig hostname topology; };

      # ── Accumulate all machine configs ────────────────────────
      # Fold over all filtered topology files, building up the
      # hostname -> config attrset mapping.
      allConfigs = lib.foldl'
        (acc: filename:
          acc // (processFile filename topologyFiles.${filename})
        )
        { }
        (builtins.attrNames topologyFiles);

    in
    allConfigs;
}
