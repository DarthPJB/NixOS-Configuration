# lib/topology_library.nix
# Ketchup — The topology generator library.
#
# ═══════════════════════════════════════════════════════════════════════════════
# THE CORE PRINCIPLE — STATED IN FULL (REPEATED FOR EMPHASIS, NO ABBREVIATIONS)
# ═══════════════════════════════════════════════════════════════════════════════
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# EVERY VARIATION:
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
# See lib/topology/PRINCIPLE.md — this principle appears in full at the top of every generator, module, and doc.
# ═══════════════════════════════════════════════════════════════════════════════
#
# Usage:
#   ketchup = import ./lib/topology_library.nix { inherit lib; };
#   ketchup.generators.genFirewall topology.firewall
#   ketchup.generators.genDns { inherit (topology) dns lan_dhcp; }
#   ketchup.generators.genNginx topology
#   ketchup.generators.genBackup topology.backup
{ lib }:
{
  # --- Pure generators (JSON → config attrset) ---
  generators = {
    genFirewall = import ./topology/genFirewall.nix { inherit lib; };
    genDns = import ./topology/genDns.nix { inherit lib; };
    genNginx = import ./topology/genNginx.nix { inherit lib; };
    genBackup = import ./topology/genBackup.nix { inherit lib; };
    genWireguard = import ./topology/genWireguard.nix { inherit lib; };
  };

  # --- Cross-machine topology registry (reads all JSON, builds validation) ---
  registry = import ./topology/mkRegistry.nix { inherit lib; };

  # --- Config serializer (for golden tests) ---
  serializeConfig = import ./serialize-config.nix { inherit lib; };
}
