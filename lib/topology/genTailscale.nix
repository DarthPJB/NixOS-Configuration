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
# genTailscale: topology -> config attrset
#
# Pure JSON-to-attrset function. NO BULLSHIT.
#
# Input: full topology JSON
# Output: { services.tailscale = { enable = true; useRoutingFeatures = "..."; extraSetFlags = [...]; }; }
#
# Reads topology.advertised_tailscale_routes (array of CIDR strings).
# If routes exist: enable tailscale as subnet router with advertised routes.
# If tailscale coordinate exists but no routes: enable tailscale without routing.
# If neither: return { }.
#
# Callable in total isolation:
#   gen = import ./lib/topology/genTailscale.nix { inherit lib; };
#   gen (builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json))
#
# Does NOT:
# - Reference the NixOS module system (no `config`, no `lib.mkIf`)
# - Take a hostname parameter
# - Read filesystem paths relative to module location
# - Have legacy fallback paths
topology:
let
  inherit (builtins) any concatStringsSep;
  coords = topology.coordinate or [ ];
  routes = topology.advertised_tailscale_routes or [ ];

  # Check if tailscale coordinate exists
  hasTailscaleCoord = any
    (c: (c.plane_name or "") == "tailscale-platonic")
    coords;

  # Build extraSetFlags with advertised routes
  routeFlags =
    if routes != [ ] then
      [ "--advertise-routes=${concatStringsSep "," routes}" ]
    else [ ];

in
if routes != [ ] then {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraSetFlags = routeFlags;
  };
}
else if hasTailscaleCoord then {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
  };
}
else { }
