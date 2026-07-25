# lib/mayo_library.nix
# Mayo — Shared helpers and utilities for Ketchup and Secret-Sauce.
#
# Contains cross-cutting utilities used by both the topology engine (Ketchup)
# and the machine configurations (Secret-Sauce).
#
# Usage:
#   mayo = import ./lib/mayo_library.nix { inherit lib; };
#   mayo.safeLookup attrs name default
#   mayo.mkKnownHosts topology
{ lib }:
let
  utils = import ./topology/utils.nix { inherit lib; };
in
{
  # --- Topology utilities (also exported by Ketchup) ---
  inherit (utils) dedupPreserveOrder safeLookup isIP isCIDR isIPv4 isMAC isPort normalizePath;

  # --- SSH known hosts generator ---
  mkKnownHosts = import ./mkKnownHosts.nix;

  # --- Network interface helpers ---
  networkInterfaces = import ./network-interfaces.nix;
}
