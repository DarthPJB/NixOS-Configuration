# Unit tests for the genDnsmasqHorizons generator
# Run with: nix --option builders '' eval --impure --json --expr 'import /tmp/nixos-planar-topology/tests/topology/genDnsmasqHorizons.nix'
#
# These tests verify that genDnsmasqHorizons produces correct dnsmasq
# settings from a sample horizon settings input.
#
# Architecture: §4.4 of the planar topology plan (rev 8).

let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;

  # Sample horizon with two coordinate entries (wg + lan)
  horizon = {
    coordinate = [
      { plane_name = "wg"; subnet = "10.88.127.0/24"; peer_id = 1; trust = 3; interface = "wireg0"; }
      { plane_name = "cortex-alpha.lan"; subnet = "10.88.128.0/24"; peer_id = 1; trust = 1; interface = "enp3s0"; }
    ];
    hub_of = [];
    effective_icmp = {};
    vhostPlanes = {};
  };

  result = (import /tmp/nixos-planar-topology/lib/topology/genDnsmasqHorizons.nix { inherit lib; }) horizon;

  isAttrs = builtins.isAttrs result;
  hasListenAddress = result ? listen-address;
  hasBindInterfaces = result ? bind-interfaces;
  hasLocaliseQueries = result ? localise-queries;
  hasAuthServer = result ? auth-server;
  hasServer = result ? server;
  listenCount = builtins.length (result.listen-address or []);
  hasWgAddr = builtins.elem "10.88.127.1" (result.listen-address or []);
  hasLanAddr = builtins.elem "10.88.128.1" (result.listen-address or []);
  bindIsTrue = result.bind-interfaces or false == true;
  localiseIsTrue = result.localise-queries or false == true;

in
{
  passed = isAttrs && hasListenAddress && listenCount == 2 && hasWgAddr && hasLanAddr && bindIsTrue && localiseIsTrue;
  total = 1;
  failed = if isAttrs && hasListenAddress && listenCount == 2 && hasWgAddr && hasLanAddr && bindIsTrue && localiseIsTrue then 0 else 1;
  checks = [
    { name = "is_attrs"; expected = true; actual = isAttrs; pass = isAttrs; }
    { name = "has_listen_address"; expected = true; actual = hasListenAddress; pass = hasListenAddress; }
    { name = "has_bind_interfaces"; expected = true; actual = hasBindInterfaces; pass = hasBindInterfaces; }
    { name = "has_localise_queries"; expected = true; actual = hasLocaliseQueries; pass = hasLocaliseQueries; }
    { name = "has_auth_server"; expected = true; actual = hasAuthServer; pass = hasAuthServer; }
    { name = "has_server"; expected = true; actual = hasServer; pass = hasServer; }
    { name = "listen_count"; expected = 2; actual = listenCount; pass = listenCount == 2; }
    { name = "has_wg_addr"; expected = true; actual = hasWgAddr; pass = hasWgAddr; }
    { name = "has_lan_addr"; expected = true; actual = hasLanAddr; pass = hasLanAddr; }
    { name = "bind_is_true"; expected = true; actual = bindIsTrue; pass = bindIsTrue; }
    { name = "localise_is_true"; expected = true; actual = localiseIsTrue; pass = localiseIsTrue; }
  ];
}
