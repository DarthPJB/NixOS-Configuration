# Unit tests for the horizon transformer (mkHorizons.nix)
# Run with: nix --option builders '' eval --impure --json --expr 'import /tmp/nixos-planar-topology/tests/topology/mkHorizons.nix'
#
# These tests validate that mkHorizons produces correct per-machine
# horizon settings from the registry.
#
# Architecture: §4.2 of the planar topology plan (rev 8).

let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  registry = import /tmp/nixos-planar-topology/lib/topology/mkRegistry.nix { inherit lib; };
  mkHorizons = (import /tmp/nixos-planar-topology/lib/topology/mkHorizons.nix { inherit lib; }).mkHorizons;

  inherit (builtins) all length attrNames filter;

  # Test: unknown host produces error
  testUnknownHost = {
    name = "unknown_host_error";
    pass =
      let
        h = mkHorizons { inherit registry; hostname = "__nonexistent__"; };
      in
      (length h.errors) > 0
      && h.coordinate == [ ]
      && h.hub_of == [ ]
      && h.effective_icmp == { }
      && h.vhosts == { };
    detail =
      let
        h = mkHorizons { inherit registry; hostname = "__nonexistent__"; };
      in
      {
        errors = h.errors;
        coordinate = h.coordinate;
      };
  };

  # Test: cortex-alpha horizon (hub with 4 coordinates)
  testCortexAlphaCoordinateCount =
    let
      h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
      actual = length h.coordinate;
      expected = 4;
    in
    {
      name = "cortex-alpha_coordinate_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  testCortexAlphaHubOfCount =
    let
      h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
      actual = length h.hub_of;
      expected = 4;
    in
    {
      name = "cortex-alpha_hub_of_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  testCortexAlphaIcmpInterfaces =
    let
      h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
      actual = attrNames h.effective_icmp;
      expected = [ "enp2s0" "enp3s0" "tailscale0" "wireg0" ];
    in
    {
      name = "cortex-alpha_icmp_interfaces";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  testCortexAlphaIcmpDefaultValues =
    let
      h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
      icmp = h.effective_icmp;
      # All should have default { pmtud = true; ping = false; }
      allDefaults = all
        (iface:
          icmp.${iface}.pmtud == true && icmp.${iface}.ping == false
        )
        (attrNames icmp);
    in
    {
      name = "cortex-alpha_icmp_default_values";
      pass = allDefaults;
      detail = icmp;
    };

  testCortexAlphaNoErrors =
    let
      h = mkHorizons { inherit registry; hostname = "cortex-alpha"; };
    in
    {
      name = "cortex-alpha_no_errors";
      pass = h.errors == [ ];
      actual = h.errors;
    };

  # Test: remote-worker leaf (single coordinate, no hub_of)
  testRemoteWorkerCoordinateCount =
    let
      h = mkHorizons { inherit registry; hostname = "remote-worker"; };
      actual = length h.coordinate;
      expected = 1;
    in
    {
      name = "remote-worker_coordinate_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  testRemoteWorkerNoHubOf =
    let
      h = mkHorizons { inherit registry; hostname = "remote-worker"; };
      actual = length h.hub_of;
      expected = 0;
    in
    {
      name = "remote-worker_no_hub_of";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  testRemoteWorkerIcmpInterface =
    let
      h = mkHorizons { inherit registry; hostname = "remote-worker"; };
      actual = attrNames h.effective_icmp;
      expected = [ "wireg0" ];
    in
    {
      name = "remote-worker_icmp_interface";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # Test: dlyon has 1 coordinate
  testDlyonCoordinateCount =
    let
      h = mkHorizons { inherit registry; hostname = "dlyon"; };
      actual = length h.coordinate;
      expected = 1;
    in
    {
      name = "dlyon_coordinate_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # Test: LINDA has 3 coordinates (wg + cortex-alpha.lan + tailscale-platonic)
  testLINDACoordinateCount =
    let
      h = mkHorizons { inherit registry; hostname = "LINDA"; };
      actual = length h.coordinate;
      expected = 3;
    in
    {
      name = "LINDA_coordinate_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── Synthetic registries for requires_routes tests ──────────────

  # Test 1: Valid hub — hub-host sits on both via_subnet and to_subnet
  hubSatisfiedRegistry = {
    hosts = {
      test-host = {
        hostname = "test-host";
        coordinate = [
          { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
        ];
        requires_routes = [
          { via_subnet = "10.0.1.0/24"; to_subnet = "10.0.2.0/24"; reason = "test: need route to office"; }
        ];
      };
      hub-host = {
        hostname = "hub-host";
        trust = 5;
        hub_of = [
          { plane_name = "p1"; subnet = "10.0.1.0/24"; }
          { plane_name = "p2"; subnet = "10.0.2.0/24"; }
        ];
        coordinate = [
          { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 2; trust = 1; interface = "eth0"; }
          { plane_name = "p2"; subnet = "10.0.2.0/24"; peer_id = 1; trust = 1; interface = "eth1"; }
        ];
      };
    };
  };

  # Test 2: No hub, no BFS path — isolated subnets
  noHubRegistry = {
    hosts = {
      test-host = {
        hostname = "test-host";
        coordinate = [
          { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
        ];
        requires_routes = [
          { via_subnet = "10.0.1.0/24"; to_subnet = "10.0.3.0/24"; reason = "test: no hub exists"; }
        ];
      };
      other-host = {
        hostname = "other-host";
        coordinate = [
          { plane_name = "p3"; subnet = "10.0.3.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
        ];
      };
    };
  };

  # Test 3: Valid BFS — relay-b connects from_subnet to to_subnet via chain
  bfsSatisfiedRegistry = {
    hosts = {
      leaf-a = {
        hostname = "leaf-a";
        coordinate = [
          { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
        ];
        requires_routes = [
          { via_subnet = "10.0.1.0/24"; to_subnet = "10.0.3.0/24"; reason = "test: BFS route needed"; }
        ];
      };
      relay-b = {
        hostname = "relay-b";
        coordinate = [
          { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 2; trust = 1; interface = "eth0"; }
          { plane_name = "p2"; subnet = "10.0.2.0/24"; peer_id = 1; trust = 1; interface = "eth1"; }
        ];
      };
      leaf-c = {
        hostname = "leaf-c";
        coordinate = [
          { plane_name = "p2"; subnet = "10.0.2.0/24"; peer_id = 2; trust = 1; interface = "eth0"; }
          { plane_name = "p3"; subnet = "10.0.3.0/24"; peer_id = 1; trust = 1; interface = "eth1"; }
        ];
      };
    };
  };

  # Test 4: No BFS — subnets exist but no connectivity between them
  noBfsRegistry = {
    hosts = {
      leaf-a = {
        hostname = "leaf-a";
        coordinate = [
          { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
        ];
        requires_routes = [
          { via_subnet = "10.0.1.0/24"; to_subnet = "10.0.4.0/24"; reason = "test: no path at all"; }
        ];
      };
      isolated-host = {
        hostname = "isolated-host";
        coordinate = [
          { plane_name = "p3"; subnet = "10.0.4.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
        ];
      };
    };
  };

  # ── requires_routes tests ──────────────────────────────────────

  testRequiresRoutesValidHub = {
    name = "requires_routes_valid_hub";
    pass =
      let
        h = mkHorizons { registry = hubSatisfiedRegistry; hostname = "test-host"; };
      in
      h.errors == [ ];
    detail =
      let
        h = mkHorizons { registry = hubSatisfiedRegistry; hostname = "test-host"; };
      in
      { errors = h.errors; };
  };

  testRequiresRoutesNoHub = {
    name = "requires_routes_no_hub";
    pass =
      let
        h = mkHorizons { registry = noHubRegistry; hostname = "test-host"; };
      in
      (length h.errors) > 0
      && lib.any (e: lib.hasInfix "no route path exists" e) h.errors;
    detail =
      let
        h = mkHorizons { registry = noHubRegistry; hostname = "test-host"; };
      in
      { errors = h.errors; };
  };

  testRequiresRoutesValidBfs = {
    name = "requires_routes_valid_bfs";
    pass =
      let
        h = mkHorizons { registry = bfsSatisfiedRegistry; hostname = "leaf-a"; };
      in
      h.errors == [ ];
    detail =
      let
        h = mkHorizons { registry = bfsSatisfiedRegistry; hostname = "leaf-a"; };
      in
      { errors = h.errors; };
  };

  testRequiresRoutesNoBfs = {
    name = "requires_routes_no_bfs";
    pass =
      let
        h = mkHorizons { registry = noBfsRegistry; hostname = "leaf-a"; };
      in
      (length h.errors) > 0
      && lib.any (e: lib.hasInfix "no route path exists" e) h.errors;
    detail =
      let
        h = mkHorizons { registry = noBfsRegistry; hostname = "leaf-a"; };
      in
      { errors = h.errors; };
  };

  # ── Missing required fields test ───────────────────────────────

  testRequiresRoutesMissingFields = {
    name = "requires_routes_missing_fields";
    pass =
      let
        missingRegistry = {
          hosts = {
            test-host = {
              hostname = "test-host";
              coordinate = [
                { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
              ];
              requires_routes = [
                { via_subnet = "10.0.1.0/24"; reason = "missing to_subnet"; }
              ];
            };
          };
        };
        h = mkHorizons { registry = missingRegistry; hostname = "test-host"; };
      in
      (length h.errors) > 0
      && lib.any (e: lib.hasInfix "missing required fields" e) h.errors;
    detail =
      let
        missingRegistry = {
          hosts = {
            test-host = {
              hostname = "test-host";
              coordinate = [
                { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
              ];
              requires_routes = [
                { via_subnet = "10.0.1.0/24"; reason = "missing to_subnet"; }
              ];
            };
          };
        };
        h = mkHorizons { registry = missingRegistry; hostname = "test-host"; };
      in
      { errors = h.errors; };
  };

  testRequiresRoutesLocalSubnet = {
    name = "requires_routes_local_subnet";
    pass =
      let
        # Host already on to_subnet — R2 shortcut should give 0 errors
        localRegistry = {
          hosts = {
            test-host = {
              hostname = "test-host";
              coordinate = [
                { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
                { plane_name = "p2"; subnet = "10.0.2.0/24"; peer_id = 2; trust = 1; interface = "eth1"; }
              ];
              requires_routes = [
                { via_subnet = "10.0.1.0/24"; to_subnet = "10.0.2.0/24"; reason = "test: already local"; }
              ];
            };
          };
        };
        h = mkHorizons { registry = localRegistry; hostname = "test-host"; };
      in
      h.errors == [ ];
    detail =
      let
        localRegistry = {
          hosts = {
            test-host = {
              hostname = "test-host";
              coordinate = [
                { plane_name = "p1"; subnet = "10.0.1.0/24"; peer_id = 1; trust = 1; interface = "eth0"; }
                { plane_name = "p2"; subnet = "10.0.2.0/24"; peer_id = 2; trust = 1; interface = "eth1"; }
              ];
              requires_routes = [
                { via_subnet = "10.0.1.0/24"; to_subnet = "10.0.2.0/24"; reason = "test: already local"; }
              ];
            };
          };
        };
        h = mkHorizons { registry = localRegistry; hostname = "test-host"; };
      in
      { errors = h.errors; };
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
    testRequiresRoutesValidHub
    testRequiresRoutesNoHub
    testRequiresRoutesValidBfs
    testRequiresRoutesNoBfs
    testRequiresRoutesMissingFields
    testRequiresRoutesLocalSubnet
  ];

  passed = all (c: c.pass) checks;

in
{
  passed = passed;
  total = length checks;
  failed = length (filter (c: !c.pass) checks);
  checks = checks;
}
