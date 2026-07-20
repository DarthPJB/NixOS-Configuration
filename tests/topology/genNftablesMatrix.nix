# Unit tests for the genNftablesMatrix generator
# Run with: nix --option builders '' eval --impure --json --expr 'import /tmp/nixos-planar-topology/tests/topology/genNftablesMatrix.nix'
#
# These tests verify that genNftablesMatrix produces a valid nftables
# ruleset string from a sample horizon settings input.
#
# Architecture: §4.4 of the planar topology plan (rev 8).

let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;

  # Sample horizon with WG, LAN, and WAN coordinates plus hub_of entries
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
    vhostPlanes = { };
  };

  result = (import /tmp/nixos-planar-topology/lib/topology/genNftablesMatrix.nix { inherit lib; }) horizon;

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

in
{
  passed = isString && hasPmtud && hasWanIf && hasMasquerade && hasInputChain && hasForwardChain
    && hasPreroutingChain && hasPostroutingChain && hasNatTable && hasFilterTable;
  total = 1;
  failed =
    if isString && hasPmtud && hasWanIf && hasMasquerade && hasInputChain && hasForwardChain
      && hasPreroutingChain && hasPostroutingChain && hasNatTable && hasFilterTable then 0 else 1;
  checks = [
    { name = "is_string"; expected = true; actual = isString; pass = isString; }
    { name = "has_pmtud_rule"; expected = true; actual = hasPmtud; pass = hasPmtud; }
    { name = "has_ct_established_accept"; expected = true; actual = hasIcmpAccept; pass = hasIcmpAccept; }
    { name = "has_lo_accept"; expected = true; actual = hasLoAccept; pass = hasLoAccept; }
    { name = "has_wan_if_enp2s0"; expected = true; actual = hasWanIf; pass = hasWanIf; }
    { name = "has_masquerade"; expected = true; actual = hasMasquerade; pass = hasMasquerade; }
    { name = "has_private_wg_subnet"; expected = true; actual = hasPrivateWgSubnet; pass = hasPrivateWgSubnet; }
    { name = "has_private_lan_subnet"; expected = true; actual = hasPrivateLanSubnet; pass = hasPrivateLanSubnet; }
    { name = "has_input_chain"; expected = true; actual = hasInputChain; pass = hasInputChain; }
    { name = "has_forward_chain"; expected = true; actual = hasForwardChain; pass = hasForwardChain; }
    { name = "has_prerouting_chain"; expected = true; actual = hasPreroutingChain; pass = hasPreroutingChain; }
    { name = "has_postrouting_chain"; expected = true; actual = hasPostroutingChain; pass = hasPostroutingChain; }
    { name = "has_nat_table"; expected = true; actual = hasNatTable; pass = hasNatTable; }
    { name = "has_filter_table"; expected = true; actual = hasFilterTable; pass = hasFilterTable; }
  ];
}
