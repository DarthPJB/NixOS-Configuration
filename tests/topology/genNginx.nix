# Unit tests for the genNginx generator — flake check, ${self} is the flake source.
#
# These tests verify that genNginx produces correct NixOS nginx config
# from a sample horizon settings input (new schema vhosts path).
#
# Architecture: §4.4 of the planar topology plan (rev 8).

{ self, lib }:
let
  # Sample horizon settings with a few vhosts (new schema path)
  horizon = {
    coordinate = [
      { plane_name = "wg"; subnet = "10.88.127.0/24"; peer_id = 1; trust = 3; interface = "wireg0"; }
    ];
    hub_of = [ ];
    effective_icmp = { wireg0 = { pmtud = true; ping = false; }; };
    vhosts = {
      "code.johnbargman.net" = [
        { subnet = "10.88.127.0/24"; reason = "Gitea on WG"; proxy_to = "10.88.127.3:80"; }
      ];
      "johnbargman.net" = [
        { subnet = "10.88.127.0/24"; reason = "Public webroot on WG"; }
      ];
    };
  };

  # Call with two args: settings + hostname (hostname ignored for new schema path)
  result = (import "${self}/lib/topology/genNginx.nix" { inherit lib; }) horizon "test";

  # Result should be a NixOS config attrset with services.nginx.virtualHosts
  isConfig = builtins.isAttrs result && result ? services.nginx.virtualHosts;
  vhosts = if isConfig then result.services.nginx.virtualHosts else { };
  vhostCount = builtins.length (builtins.attrNames vhosts);
  hasCode = vhosts ? "code.johnbargman.net";
  hasRoot = vhosts ? "johnbargman.net";

  # Check that the proxy vhost emits proxyPass
  codeEntry = if hasCode then vhosts."code.johnbargman.net" else { };
  hasProxyForCode = hasCode
    && codeEntry.locations."/" ? proxyPass
    && codeEntry.locations."/".proxyPass == "http://10.88.127.3:80";

  # Check that the static vhost has no proxyPass (empty locations)
  rootEntry = if hasRoot then vhosts."johnbargman.net" else { };
  hasNoProxyForRoot = hasRoot
    && !(rootEntry.locations."/" ? proxyPass);

  # Check that acme group is added
  hasAcmeGroup = builtins.elem "acme" (result.users.users.nginx.extraGroups or [ ]);

in
{
  passed = isConfig && vhostCount > 0 && hasCode && hasRoot && hasProxyForCode && hasNoProxyForRoot && hasAcmeGroup;
  total = 1;
  failed = if isConfig && vhostCount > 0 && hasCode && hasRoot && hasProxyForCode && hasNoProxyForRoot && hasAcmeGroup then 0 else 1;
  checks = [
    { name = "is_config_attrset"; expected = true; actual = isConfig; pass = isConfig; }
    { name = "vhost_count"; expected = 2; actual = vhostCount; pass = vhostCount == 2; }
    { name = "has_code_johnbargman_net"; expected = true; actual = hasCode; pass = hasCode; }
    { name = "has_johnbargman_net"; expected = true; actual = hasRoot; pass = hasRoot; }
    { name = "has_proxy_for_code"; expected = true; actual = hasProxyForCode; pass = hasProxyForCode; }
    { name = "no_proxy_for_root"; expected = true; actual = hasNoProxyForRoot; pass = hasNoProxyForRoot; }
    { name = "has_acme_group"; expected = true; actual = hasAcmeGroup; pass = hasAcmeGroup; }
  ];
}
