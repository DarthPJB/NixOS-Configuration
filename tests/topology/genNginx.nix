# Unit tests for the genNginx generator
# Run with: nix --option builders '' eval --impure --json --expr 'import /tmp/nixos-planar-topology/tests/topology/genNginx.nix'
#
# These tests verify that genNginx produces correct vhost stanzas
# from a sample horizon settings input.
#
# Architecture: §4.4 of the planar topology plan (rev 8).

let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;

  # Sample horizon settings with a few vhosts
  horizon = {
    coordinate = [
      { plane_name = "wg"; subnet = "10.88.127.0/24"; peer_id = 1; trust = 3; interface = "wireg0"; }
    ];
    hub_of = [];
    effective_icmp = { wireg0 = { pmtud = true; ping = false; }; };
    vhostPlanes = {
      "code.johnbargman.net" = [
        { subnet = "10.88.127.0/24"; reason = "Gitea on WG"; proxy_to = "10.88.127.3:80"; }
      ];
      "johnbargman.net" = [
        { subnet = "10.88.127.0/24"; reason = "Public webroot on WG"; }
      ];
    };
  };

  result = (import /tmp/nixos-planar-topology/lib/topology/genNginx.nix { inherit lib; }) horizon;

  isList = builtins.isList result;
  vhostCount = builtins.length result;
  serverNames = map (s: s.serverName) result;

  # Check that both expected vhosts are present
  hasCode = builtins.elem "code.johnbargman.net" serverNames;
  hasRoot = builtins.elem "johnbargman.net" serverNames;

  # Check that the proxy vhost emits proxyPass
  codeEntry = builtins.head (builtins.filter (s: s.serverName == "code.johnbargman.net") result);
  hasProxyForCode = codeEntry.locations."/" ? proxyPass && codeEntry.locations."/".proxyPass == "http://10.88.127.3:80";

  # Check that the static vhost has no proxyPass (empty locations)
  rootEntry = builtins.head (builtins.filter (s: s.serverName == "johnbargman.net") result);
  hasNoProxyForRoot = !(rootEntry.locations."/" ? proxyPass);

in
{
  passed = isList && vhostCount > 0 && hasCode && hasRoot;
  total = 1;
  failed = if isList && vhostCount > 0 && hasCode && hasRoot then 0 else 1;
  checks = [
    { name = "is_list"; expected = true; actual = isList; pass = isList; }
    { name = "vhost_count"; expected = 2; actual = vhostCount; pass = vhostCount == 2; }
    { name = "has_code_johnbargman_net"; expected = true; actual = hasCode; pass = hasCode; }
    { name = "has_johnbargman_net"; expected = true; actual = hasRoot; pass = hasRoot; }
    { name = "has_proxy_for_code"; expected = true; actual = hasProxyForCode; pass = hasProxyForCode; }
    { name = "no_proxy_for_root"; expected = true; actual = hasNoProxyForRoot; pass = hasNoProxyForRoot; }
  ];
}
