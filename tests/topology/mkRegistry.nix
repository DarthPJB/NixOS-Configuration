# Unit tests for the topology registry
# Run with: nix --option builders '' eval --impure --json --expr 'import /tmp/nixos-planar-topology/tests/topology/mkRegistry.nix'
#
# These tests lock down the current state of the registry to detect
# regressions as data quality issues are fixed.
#
# Expected state (after Phase 0):
#   - hosts count: 36 (35 per-host JSON files + cortex-alpha.json)
#   - planes count: 4 (cortex-alpha's 4 hub_of planes; building-b lacks hub_of)
#   - errors count: 8 (1 dangling coordinate, 6 peer_id collisions, 1 invalid CIDR)
#
# Architecture: §4.1 of the planar topology plan (rev 8).

let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  registry = import /tmp/nixos-planar-topology/lib/topology/mkRegistry.nix { inherit lib; };

  inherit (builtins) elem all length attrNames attrValues filter;

  hosts = registry.hosts;
  planes = registry.planes;
  errors = registry.errors;
  hostnames = attrNames hosts;

  # Helper: count errors matching a substring
  countErrorsWithSubstr = substr:
    length (filter (e: lib.hasInfix substr e) errors);

  # ── Test 1: Host count ──────────────────────────────────────
  testHostsCount =
    let
      actual = length hostnames;
      expected = 36;
    in
    {
      name = "hosts_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── Test 2: Plane count ─────────────────────────────────────
  testPlanesCount =
    let
      actual = length (attrNames planes);
      expected = 4;
    in
    {
      name = "planes_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── Test 3: Error count ─────────────────────────────────────
  testErrorsCount =
    let
      actual = length errors;
      expected = 8;
    in
    {
      name = "errors_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── Test 4: Known host present ──────────────────────────────
  testCortexAlphaExists =
    let
      expected = "cortex-alpha";
    in
    {
      name = "cortex-alpha_exists";
      expected = expected;
      actual = elem expected hostnames;
      pass = elem expected hostnames;
    };

  # ── Test 5: Known host has expected fields ──────────────────
  testCortexAlphaFields =
    let
      actual = attrNames (hosts.cortex-alpha or { });
      # cortex-alpha.json has 7 fields (no "role" field in JSON format)
      expected = [
        "advertised_tailscale_routes"
        "coordinate"
        "default_response"
        "hostname"
        "hub_of"
        "public_key_file"
        "trust"
      ];
    in
    {
      name = "cortex-alpha_fields";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── Test 6: Known host has expected hostname value ──────────
  testCortexAlphaHostname =
    let
      actual = hosts.cortex-alpha.hostname or null;
      expected = "cortex-alpha";
    in
    {
      name = "cortex-alpha_hostname_value";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── Test 7: Known host has 4 hub_of entries ─────────────────
  testCortexAlphaHubOfCount =
    let
      actual = length (hosts.cortex-alpha.hub_of or [ ]);
      expected = 4;
    in
    {
      name = "cortex-alpha_hub_of_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── Test 8: building-b dangling coordinate error ────────────
  testErrorBuildingBDangling =
    let
      actual = countErrorsWithSubstr
        "building-b: coordinate 'building-b-lan/10.89.128.1' has no matching hub_of";
    in
    {
      name = "error_building-b_dangling_coordinate";
      expected = 1;
      actual = actual;
      pass = actual == 1;
    };

  # ── Test 9: building-b invalid CIDR error ───────────────────
  testErrorBuildingBInvalidCIDR =
    let
      actual = countErrorsWithSubstr
        "building-b: subnet '10.89.128.1' is not valid CIDR";
    in
    {
      name = "error_building-b_invalid_cidr";
      expected = 1;
      actual = actual;
      pass = actual == 1;
    };

  # ── Test 10: Peer ID collision count (must be exactly 6) ────
  testPeerIdCollisionCount =
    let
      collisionErrors = filter (e: lib.hasInfix "peer_id collision" e) errors;
      actual = length collisionErrors;
      expected = 6;
    in
    {
      name = "peer_id_collision_count";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── Test 11: Specific peer_id collision (wg/20) ─────────────
  testPeerIdCollisionWg20 =
    let
      actual = countErrorsWithSubstr
        "terminal-zero-2:peer_id=20";
    in
    {
      name = "peer_id_collision_wg_20";
      expected = 1;
      actual = actual;
      pass = actual == 1;
    };

  # ── Test 12: Specific peer_id collision (wg/21 triple) ──────
  testPeerIdCollisionWg21 =
    let
      actual = countErrorsWithSubstr
        "terminal-nx-01-2:peer_id=21";
    in
    {
      name = "peer_id_collision_wg_21";
      expected = 1;
      actual = actual;
      pass = actual == 1;
    };

  # ── Test 13: No planes without a hub ────────────────────────
  # All 4 planes should have a non-null hub
  testAllPlanesHaveHub =
    let
      planeList = attrValues planes;
      missingHub = filter (p: p.hub or null == null) planeList;
      actual = length missingHub;
      expected = 0;
    in
    {
      name = "all_planes_have_hub";
      expected = expected;
      actual = actual;
      pass = actual == expected;
    };

  # ── All checks ──────────────────────────────────────────────
  checks = [
    testHostsCount
    testPlanesCount
    testErrorsCount
    testCortexAlphaExists
    testCortexAlphaFields
    testCortexAlphaHostname
    testCortexAlphaHubOfCount
    testErrorBuildingBDangling
    testErrorBuildingBInvalidCIDR
    testPeerIdCollisionCount
    testPeerIdCollisionWg20
    testPeerIdCollisionWg21
    testAllPlanesHaveHub
  ];

  passed = all (c: c.pass) checks;

in
{
  passed = passed;
  total = length checks;
  failed = length (filter (c: !c.pass) checks);
  checks = checks;
}
