# Unit tests for the horizon transformer (mkHorizons.nix)
# Run with: nix --option builders '' eval --impure --json --expr 'import /tmp/nixos-planar-topology/tests/topology/mkHorizons.nix'
#
# These tests validate that mkHorizons produces correct per-machine
# horizon settings from the registry.
#
# Architecture: §4.2 of the planar topology plan (rev 8).

let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  registry = import /tmp/nixos-planar-topology/lib/topology/mkRegistry.nix { inherit lib; };
  mkHorizons = (import /tmp/nixos-planar-topology/lib/topology/mkHorizons.nix { inherit lib; }).mkHorizons;

  inherit (builtins) elem all length attrNames attrValues filter;

  # Helper: test that horizon has expected structure for a hub host
  testHubHorizon = hostname: {
    name = "${hostname}_horizon";
    pass =
      let
        h = mkHorizons { inherit registry; inherit hostname; };
        hasCoords  = (length h.coordinate) > 0;
        hasIcmp    = (length (attrNames h.effective_icmp)) > 0;
        hasHubOf   = (length h.hub_of) > 0;
        noErrors   = h.errors == [];
      in
      hasCoords && hasIcmp && hasHubOf && noErrors;
    detail =
      let
        h = mkHorizons { inherit registry; inherit hostname; };
      in {
        coordinate_count = length h.coordinate;
        hub_of_count = length h.hub_of;
        icmp_interface_count = length (attrNames h.effective_icmp);
        errors = h.errors;
        warnings = h.warnings;
      };
  };

  # Helper: test that horizon works for a leaf host
  testLeafHorizon = hostname: {
    name = "${hostname}_leaf_horizon";
    pass =
      let
        h = mkHorizons { inherit registry; inherit hostname; };
        hasCoords  = (length h.coordinate) > 0;
        hasIcmp    = (length (attrNames h.effective_icmp)) > 0;
        noHubOf    = (length h.hub_of) == 0;
        noErrors   = h.errors == [];
      in
      hasCoords && hasIcmp && noHubOf && noErrors;
    detail =
      let
        h = mkHorizons { inherit registry; inherit hostname; };
      in {
        coordinate_count = length h.coordinate;
        hub_of_count = length h.hub_of;
        icmp_interface_count = length (attrNames h.effective_icmp);
        errors = h.errors;
        warnings = h.warnings;
      };
  };

  # Test: unknown host produces error
  testUnknownHost = {
    name = "unknown_host_error";
    pass =
      let
        h = mkHorizons { inherit registry; hostname = "__nonexistent__"; };
      in
        (length h.errors) > 0
        && h.coordinate == []
        && h.hub_of == []
        && h.effective_icmp == {}
        && h.vhostPlanes == {};
    detail =
      let
        h = mkHorizons { inherit registry; hostname = "__nonexistent__"; };
      in {
        errors = h.errors;
        coordinate = h.coordinate;
      };
  };

  # Test: cortex-alpha horizon (hub with 4 coordinates)
  testCortexAlphaCoordinateCount = let
    h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
    actual = length h.coordinate;
    expected = 4;
  in {
    name = "cortex-alpha_coordinate_count";
    expected = expected;
    actual = actual;
    pass = actual == expected;
  };

  testCortexAlphaHubOfCount = let
    h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
    actual = length h.hub_of;
    expected = 4;
  in {
    name = "cortex-alpha_hub_of_count";
    expected = expected;
    actual = actual;
    pass = actual == expected;
  };

  testCortexAlphaIcmpInterfaces = let
    h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
    actual = attrNames h.effective_icmp;
    expected = ["enp2s0" "enp3s0" "tailscale0" "wireg0"];
  in {
    name = "cortex-alpha_icmp_interfaces";
    expected = expected;
    actual = actual;
    pass = actual == expected;
  };

  testCortexAlphaIcmpDefaultValues = let
    h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
    icmp = h.effective_icmp;
    # All should have default { pmtud = true; ping = false; }
    allDefaults = all (iface:
      icmp.${iface}.pmtud == true && icmp.${iface}.ping == false
    ) (attrNames icmp);
  in {
    name = "cortex-alpha_icmp_default_values";
    pass = allDefaults;
    detail = icmp;
  };

  testCortexAlphaNoErrors = let
    h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
  in {
    name = "cortex-alpha_no_errors";
    pass = h.errors == [];
    actual = h.errors;
  };

  # Test: remote-worker leaf (single coordinate, no hub_of)
  testRemoteWorkerCoordinateCount = let
    h = mkHorizons { inherit registry; hostname = "remote-worker"; };
    actual = length h.coordinate;
    expected = 1;
  in {
    name = "remote-worker_coordinate_count";
    expected = expected;
    actual = actual;
    pass = actual == expected;
  };

  testRemoteWorkerNoHubOf = let
    h = mkHorizons { inherit registry; hostname = "remote-worker"; };
    actual = length h.hub_of;
    expected = 0;
  in {
    name = "remote-worker_no_hub_of";
    expected = expected;
    actual = actual;
    pass = actual == expected;
  };

  testRemoteWorkerIcmpInterface = let
    h = mkHorizons { inherit registry; hostname = "remote-worker"; };
    actual = attrNames h.effective_icmp;
    expected = ["wireg0"];
  in {
    name = "remote-worker_icmp_interface";
    expected = expected;
    actual = actual;
    pass = actual == expected;
  };

  # Test: dlyon has 1 coordinate
  testDlyonCoordinateCount = let
    h = mkHorizons { inherit registry; hostname = "dlyon"; };
    actual = length h.coordinate;
    expected = 1;
  in {
    name = "dlyon_coordinate_count";
    expected = expected;
    actual = actual;
    pass = actual == expected;
  };

  # Test: LINDA has 2 coordinates (wg + cortex-alpha.lan)
  testLINDACoordinateCount = let
    h = mkHorizons { inherit registry; hostname = "LINDA"; };
    actual = length h.coordinate;
    expected = 2;
  in {
    name = "LINDA_coordinate_count";
    expected = expected;
    actual = actual;
    pass = actual == expected;
  };

  # Aggregate checks
  checks = [
    testUnknownHost
    testCortexAlphaCoordinateCount
    testCortexAlphaHubOfCount
    testCortexAlphaIcmpInterfaces
    testCortexAlphaIcmpDefaultValues
    testCortexAlphaNoErrors
    testRemoteWorkerCoordinateCount
    testRemoteWorkerNoHubOf
    testRemoteWorkerIcmpInterface
    testDlyonCoordinateCount
    testLINDACoordinateCount
  ];

  passed = all (c: c.pass) checks;

in {
  passed = passed;
  total = length checks;
  failed = length (filter (c: !c.pass) checks);
  checks = checks;
}
