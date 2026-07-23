# Unit tests for the genNftablesMatrix generator
# Run with: nix --option builders '' eval --impure --json --expr 'import /tmp/nixos-planar-topology/tests/topology/genNftablesMatrix.nix'
#
# These tests verify that genNftablesMatrix produces a valid nftables
# ruleset string from a sample horizon settings input, and that the
# isPrivateSubnet classifier correctly identifies private/reserved ranges.
#
# Architecture: §4.4 of the planar topology plan (rev 8).

let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;

  # Import the module (now returns { genRuleset, isPrivateSubnet })
  module = import /tmp/nixos-planar-topology/lib/topology/genNftablesMatrix.nix { inherit lib; };
  genRuleset = module.genRuleset;
  isPrivateSubnet = module.isPrivateSubnet;

  # ── isPrivateSubnet unit tests ─────────────────────────────────────
  subnetCases = [
    # Existing private ranges
    { name = "rfc1918_10"; subnet = "10.0.0.0/8"; expected = true; }
    { name = "rfc1918_172_16"; subnet = "172.16.0.0/12"; expected = true; }
    { name = "rfc1918_192_168"; subnet = "192.168.0.0/16"; expected = true; }
    { name = "loopback_127"; subnet = "127.0.0.0/8"; expected = true; }
    { name = "linklocal_169_254"; subnet = "169.254.0.0/16"; expected = true; }

    # CGNAT: 100.64.0.0/10
    { name = "cgnat_low_bound"; subnet = "100.64.0.0/24"; expected = true; }
    { name = "cgnat_mid"; subnet = "100.80.0.0/24"; expected = true; }
    { name = "cgnat_high_bound"; subnet = "100.127.0.0/24"; expected = true; }
    { name = "cgnat_outside"; subnet = "100.128.0.0/24"; expected = false; }
    { name = "cgnat_below"; subnet = "100.63.0.0/24"; expected = false; }

    # IPv6 ULA: fc00::/7
    { name = "ipv6_ula_fc"; subnet = "fc00::/7"; expected = true; }
    { name = "ipv6_ula_fd"; subnet = "fd00::/8"; expected = true; }
    { name = "ipv6_ula_fdaa"; subnet = "fdaa:bb:1::/48"; expected = true; }

    # IPv6 link-local: fe80::/10
    { name = "ipv6_link_local"; subnet = "fe80::/10"; expected = true; }
    { name = "ipv6_link_local_iface"; subnet = "fe80::1%eth0"; expected = true; }

    # IPv6 documentation: 2001:db8::/32
    { name = "ipv6_doc"; subnet = "2001:db8::/32"; expected = true; }
    { name = "ipv6_doc_full"; subnet = "2001:0db8::/32"; expected = true; }

    # Public WAN (not private)
    { name = "public_wan_ipv4"; subnet = "82.5.173.0/24"; expected = false; }
    { name = "public_wan_ipv6"; subnet = "2a00:1450:4000::/48"; expected = false; }
  ];

  subnetResults = map
    (t: {
      name = t.name;
      expected = t.expected;
      actual = isPrivateSubnet t.subnet;
      pass = isPrivateSubnet t.subnet == t.expected;
    })
    subnetCases;

  subnetPassed = builtins.all (r: r.pass) subnetResults;
  subnetTotal = builtins.length subnetResults;
  subnetFailed = builtins.length (builtins.filter (r: !r.pass) subnetResults);

  # ── Integration test with sample horizon ─────────────────────────
  horizon = {
    coordinate = [
      { plane_name = "wg"; subnet = "10.88.127.0/24"; peer_id = 1; trust = 3; interface = "wireg0"; }
      { plane_name = "cortex-alpha.lan"; subnet = "10.88.128.0/24"; peer_id = 1; trust = 1; interface = "enp3s0"; }
      { plane_name = "82.5.173.0/24-wan"; subnet = "82.5.173.0/24"; peer_id = 252; trust = 6; interface = "enp2s0"; }
    ];
    hub_of = [
      { plane_name = "cortex-alpha.lan"; subnet = "10.88.128.0/24"; }
      { plane_name = "wg"; subnet = "10.88.127.0/24"; }
    ];
    effective_icmp = { wireg0 = { pmtud = true; ping = false; }; enp3s0 = { pmtud = true; ping = true; }; };
    vhosts = { };
  };

  result = genRuleset horizon;

  isString = builtins.isString result;
  hasPmtud = (builtins.match ".*destination-unreachable.*" result) != null;
  hasIcmpAccept = (builtins.match ".*ct state established,related accept.*" result) != null;
  hasLoAccept = (builtins.match ".*iif \"lo\" accept.*" result) != null;
  hasWanIf = (builtins.match ".*enp2s0.*" result) != null;
  hasMasquerade = (builtins.match ".*masquerade.*" result) != null;
  hasPrivateWgSubnet = (builtins.match ".*10.88.127.0/24.*" result) != null;
  hasPrivateLanSubnet = (builtins.match ".*10.88.128.0/24.*" result) != null;
  hasInputChain = (builtins.match ".*chain input.*" result) != null;
  hasForwardChain = (builtins.match ".*chain forward.*" result) != null;
  hasPreroutingChain = (builtins.match ".*chain prerouting.*" result) != null;
  hasPostroutingChain = (builtins.match ".*chain postrouting.*" result) != null;
  hasNatTable = (builtins.match ".*table ip nat.*" result) != null;
  hasFilterTable = (builtins.match ".*table inet filter.*" result) != null;

  integrationPassed = isString && hasPmtud && hasWanIf && hasMasquerade
    && hasInputChain && hasForwardChain && hasPreroutingChain && hasPostroutingChain
    && hasNatTable && hasFilterTable;

in
{
  passed = integrationPassed && subnetPassed;
  total = 1 + subnetTotal;
  failed = (if integrationPassed then 0 else 1) + subnetFailed;
  checks = [
    # Integration checks
    { name = "integration_is_string"; expected = true; actual = isString; pass = isString; }
    { name = "integration_has_pmtud_rule"; expected = true; actual = hasPmtud; pass = hasPmtud; }
    { name = "integration_has_ct_established_accept"; expected = true; actual = hasIcmpAccept; pass = hasIcmpAccept; }
    { name = "integration_has_lo_accept"; expected = true; actual = hasLoAccept; pass = hasLoAccept; }
    { name = "integration_has_wan_if_enp2s0"; expected = true; actual = hasWanIf; pass = hasWanIf; }
    { name = "integration_has_masquerade"; expected = true; actual = hasMasquerade; pass = hasMasquerade; }
    { name = "integration_has_private_wg_subnet"; expected = true; actual = hasPrivateWgSubnet; pass = hasPrivateWgSubnet; }
    { name = "integration_has_private_lan_subnet"; expected = true; actual = hasPrivateLanSubnet; pass = hasPrivateLanSubnet; }
    { name = "integration_has_input_chain"; expected = true; actual = hasInputChain; pass = hasInputChain; }
    { name = "integration_has_forward_chain"; expected = true; actual = hasForwardChain; pass = hasForwardChain; }
    { name = "integration_has_prerouting_chain"; expected = true; actual = hasPreroutingChain; pass = hasPreroutingChain; }
    { name = "integration_has_postrouting_chain"; expected = true; actual = hasPostroutingChain; pass = hasPostroutingChain; }
    { name = "integration_has_nat_table"; expected = true; actual = hasNatTable; pass = hasNatTable; }
    { name = "integration_has_filter_table"; expected = true; actual = hasFilterTable; pass = hasFilterTable; }
  ]
  # Subnet classification checks
  ++ map (r: { name = "subnet_${r.name}"; expected = r.expected; actual = r.actual; pass = r.pass; }) subnetResults;
}
