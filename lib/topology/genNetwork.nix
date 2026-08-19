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
# genNetwork: topology -> config attrset
#
# Pure JSON-to-attrset function. NO BULLSHIT.
#
# Input: full topology JSON
# Output: { networking.interfaces.<name> = { useDHCP = false; ipv4.addresses = [...]; }; }
#
# Derives interface IP addresses from topology coordinates.
# Filters out WireGuard and Tailscale interfaces (handled by other generators).
# Only sets static IPs for interfaces with LAN/WAN coordinates.
#
# Callable in total isolation:
#   gen = import ./lib/topology/genNetwork.nix { inherit lib; };
#   gen (builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json))
#
# Does NOT:
# - Reference the NixOS module system (no `config`, no `lib.mkIf`)
# - Take a hostname parameter
# - Read filesystem paths relative to module location
# - Have legacy fallback paths
topology:
let
  inherit (builtins) filter map head elemAt;
  inherit (lib) splitString hasPrefix;

  # ── IP address helpers ──────────────────────────────────────
  # Convert (subnet, peer_id) -> IP address.
  # For subnet "10.88.128.0/24" and peer_id 1 -> "10.88.128.1"
  subnetPeerToIP = subnet: peer_id:
    let
      parts = splitString "/" subnet;
      ip = head parts;
      octets = splitString "." ip;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString peer_id}";

  # Extract prefix length from subnet CIDR notation
  # For subnet "10.88.128.0/24" -> 24
  subnetToPrefixLength = subnet:
    let
      parts = splitString "/" subnet;
    in
    lib.toInt (elemAt parts 1);

  # ── Coordinate filtering ────────────────────────────────────
  # Filter out WireGuard, Tailscale, WAN, and MAC-based interfaces.
  # These are handled by other generators or are imperatively managed.
  #
  # Only derive static IPs for hub machines (topology.wireguard present).
  # Hub machines are bare metal — we control the network.
  # Non-hub machines (VPS, cloud) — hosting provider manages the network.
  coords = topology.coordinate or [ ];
  isHub = topology ? wireguard;
  lanCoords = if !isHub then [ ] else
  filter
    (c:
      (c.plane_name or "") != "wg"
      && (c.plane_name or "") != "tailscale-platonic"
      && !hasPrefix "mac:" (c.interface or "")
      && !lib.hasSuffix "-wan" (c.plane_name or "")
      && !lib.hasSuffix ".wan" (c.plane_name or "")
    )
    coords;

  # ── Build interface config ──────────────────────────────────
  # For each LAN coordinate, derive the IP and produce interface config.
  buildInterface = coord:
    let
      ip = subnetPeerToIP coord.subnet coord.peer_id;
      prefixLength = subnetToPrefixLength coord.subnet;
    in
    {
      name = coord.interface;
      value = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = ip;
            inherit prefixLength;
          }
        ];
      };
    };

  # Build all interface configs
  interfaceConfigs = map buildInterface lanCoords;

  # Convert to attrset
  interfaces = lib.listToAttrs interfaceConfigs;

in
if lanCoords != [ ] then
  { networking.interfaces = interfaces; }
else
  { }
