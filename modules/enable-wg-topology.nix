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
# modules/enable-wg-topology.nix
# Topology-driven WireGuard module for client machines
# Phase M-1: Reads from JSON registry (mkRegistry.nix) instead of shared.nix
{ config
, lib
, self
, ...
}:

let
  # ── Phase M-1: JSON Registry ─────────────────────────────────
  registry = import ../lib/topology/mkRegistry.nix { inherit lib; };

  hostname = config.networking.hostName;
  domain = "johnbargman.net";

  # Helper: derive IP from coordinate (subnet + peer_id)
  coordToIp = coord:
    let
      parts = lib.splitString "/" coord.subnet;
      networkIp = builtins.head parts;
      octets = lib.splitString "." networkIp;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString coord.peer_id}";

  # Read public key file, returning null if missing
  readPubKey = hostnameKey:
    let
      path = ../secrets/public_keys/wireguard/wg_${hostnameKey}_pub;
    in
    if builtins.pathExists path
    then builtins.readFile path
    else null;

  # ── Machine WG coordinate ────────────────────────────────────
  myHost = registry.hosts.${hostname} or null;
  myWgCoords = builtins.filter (c: c.plane_name == "wg") (myHost.coordinate or [ ]);
  myWgCoord = if myWgCoords != [ ] then builtins.head myWgCoords else null;

  # ── Hub (cortex-alpha) coordinate ────────────────────────────
  hubHostname = "cortex-alpha";
  hubHost = registry.hosts.${hubHostname} or null;
  hubWgCoords = builtins.filter (c: c.plane_name == "wg") (hubHost.coordinate or [ ]);
  hubWgCoord = if hubWgCoords != [ ] then builtins.head hubWgCoords else null;

  # ── Derived values ───────────────────────────────────────────
  myWgIp = if myWgCoord != null then coordToIp myWgCoord else null;
  hubWgIp = if hubWgCoord != null then coordToIp hubWgCoord else null;
  listenPort = if hubHost != null then hubHost.wireguard.listen_port or 2108 else 2108;
  interfaceName = if myWgCoord != null then myWgCoord.interface else "wireg0";

  # Subnet IP for hubIps (third octet preserved, fourth = .0)
  subnetStr = if myWgCoord != null then myWgCoord.subnet else "10.88.127.0/24";
  subnetParts = lib.splitString "." (builtins.head (lib.splitString "/" subnetStr));
  subnetIp = "${builtins.elemAt subnetParts 0}.${builtins.elemAt subnetParts 1}.${builtins.elemAt subnetParts 2}.0";

  # ── Role ─────────────────────────────────────────────────────
  isHub = hostname == hubHostname;
  hubPubKey = readPubKey hubHostname;

  # ── Build peer list ──────────────────────────────────────────
  # All hosts with a wg coordinate
  allWgHostnames = builtins.attrNames (lib.filterAttrs
    (_name: host:
      builtins.any (c: c.plane_name == "wg") (host.coordinate or [ ])
    )
    registry.hosts);

  # For non-hub: only the hub peer (with endpoint)
  hubPeer =
    if isHub then [ ] else
    if hubPubKey == null then [ ] else [{
      name = hubHostname;
      publicKey = hubPubKey;
      allowedIPs = [ hubWgIp "10.88.127.0/24" ];
      endpoint = "${hubHostname}.${domain}:${toString listenPort}";
    }];

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
        let
          peerIp = coordToIp peerCoord;
        in
        [{
          name = name;
          publicKey = peerPubKey;
          allowedIPs = [ peerIp ];
        }]
      )
      allWgHostnames
    );

  peers = hubPeer ++ clientPeers;

  # ── Machine settings (for genWireguard.nix) ──────────────────
  machineSettings =
    if myWgCoord != null then {
      inherit hostname;
      interface = interfaceName;
      listenPort = listenPort;
      machineIp = myWgIp;
      isHub = isHub;
      hubIps = if isHub then [ "${myWgIp}/32" "${subnetIp}/24" ] else [ ];
      inherit peers;
    } else null;

  # Generate WireGuard config via the standard generator
  wireguardConfig =
    if machineSettings != null then
      (import ../lib/topology/genWireguard.nix { inherit lib; })
        { machines = { ${hostname} = machineSettings; }; warnings = [ ]; errors = [ ]; }
        hostname
    else null;

in
{
  options.enableWgTopology = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable topology-driven WireGuard configuration";
    };
    machineIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "WireGuard IP of this machine, set when enableWgTopology is enabled";
    };
  };

  config = lib.mkIf config.enableWgTopology.enable {
    enableWgTopology.machineIp = myWgIp;
    assertions = [
      {
        assertion = myWgCoord != null;
        message = "Machine ${hostname} not found in WireGuard topology (JSON registry)";
      }
    ];

    networking.wireguard.enable = true;
    networking.wireguard.interfaces.wireg0 = lib.mkMerge [
      wireguardConfig.networking.wireguard.interfaces.wireg0
      {
        privateKeyFile =
          config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
      }
    ];

    secrix.services.wireguard-wireg0.secrets."${hostname}".encrypted.file =
      ../secrets/private_keys/wireguard/wg_${hostname};

    services.openssh = lib.mkIf config.services.openssh.enable {
      listenAddresses = [{
        addr = myWgIp;
        port = 1108;
      }];
    };

    networking.firewall.allowedTCPPorts = [ 2108 ];
    networking.firewall.allowedUDPPorts = [ 2108 ];
  };
}
