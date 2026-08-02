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
# genForwarding: topology -> config attrset
#
# Pure JSON-to-attrset function. NO BULLSHIT.
#
# Input: full topology JSON
# Output: { networking.nftables = { enable = true; ruleset = "..."; }; }
#
# Generates nftables NAT table for port forwarding (DNAT) and masquerade.
# Reads topology.routes array and derives WAN interface + LAN subnet from coordinates.
#
# Callable in total isolation:
#   gen = import ./lib/topology/genForwarding.nix { inherit lib; };
#   gen (builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json))
#
# Does NOT:
# - Reference the NixOS module system (no `config`, no `lib.mkIf`)
# - Take a hostname parameter
# - Read filesystem paths relative to module location
# - Have legacy fallback paths
topology:
let
  inherit (builtins) filter head map elemAt;
  inherit (lib) splitString concatStringsSep hasSuffix;

  coords = topology.coordinate or [ ];
  hubOf = topology.hub_of or [ ];

  # ── WAN interface derivation ────────────────────────────────
  # Find the coordinate whose plane_name ends with "-wan" or ".wan"
  wanCoords = filter
    (c:
      hasSuffix "-wan" (c.plane_name or "")
      || hasSuffix ".wan" (c.plane_name or "")
    )
    coords;
  wanCoord = if wanCoords != [ ] then head wanCoords else null;
  wanInterface = if wanCoord != null then wanCoord.interface else "wan";

  # ── LAN subnet derivation ───────────────────────────────────
  # Priority 1: hub_of entry with plane_name ending in ".lan"
  # Priority 2: coordinate with plane_name ending in ".lan"
  lanHubOf = filter
    (h: hasSuffix ".lan" (h.plane_name or ""))
    hubOf;
  lanCoords = filter
    (c: hasSuffix ".lan" (c.plane_name or ""))
    coords;

  lanSubnet =
    if lanHubOf != [ ] then (head lanHubOf).subnet
    else if lanCoords != [ ] then (head lanCoords).subnet
    else "10.0.0.0/8";

  # ── Route processing ────────────────────────────────────────
  routes = topology.routes or [ ];

  # Generate nftables DNAT rule for a route entry
  mkDnatRule = route:
    let
      port = toString route.port;
      proto = route.proto;
      dest = route.to;
    in
    "    iifname \"${wanInterface}\" ${proto} dport ${port} dnat to ${dest}";

  # Generate all DNAT rules
  dnatRules = map mkDnatRule routes;
  allRules = concatStringsSep "\n" dnatRules;

  # ── nftables ruleset ────────────────────────────────────────
  ruleset = ''
    table ip nat {
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
    ${allRules}
      }
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        oifname "${wanInterface}" ip saddr ${lanSubnet} masquerade
      }
    }
  '';

in
if routes != [ ] then {
  networking.nftables = {
    enable = true;
    ruleset = ruleset;
  };
}
else { }
