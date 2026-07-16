{ fqdn }:
{ pkgs
, config
, lib
, ...
}:
let
  inherit fqdn;
in
{
  users.groups.acme = { };

  # trigger the actual certificate generation for additional hostname
  security.acme.certs."${fqdn}" = {
    # dnsProvider MUST be set explicitly on the per-cert level.
    # The nixpkgs nginx module (commit 377c6bcefce8) sets
    # dnsProvider = mkOverride 2000 null for any enableACME vhost,
    # which overrides the inherited default from security.acme.defaults.
    # A plain assignment here (priority 100) beats mkOverride 2000.
    dnsProvider = "gandiv5";
    environmentFile = config.secrix.system.secrets.dns01.decrypted.path;
    extraDomainNames = [ ]; # "johnbargman.com"];
    group = "nginx";
  };

  secrix.system.secrets.dns01.encrypted.file = ../secrets/gandi_dns01_token;
  # Configure ACME appropriately
  security.acme.acceptTerms = true;
  security.acme.defaults = {
    dnsProvider = "gandiv5";
    group = "acme";
    environmentFile = config.secrix.system.secrets.dns01.decrypted.path;
    # We don't need to wait for propagation since this is a local DNS server
    dnsPropagationCheck = false;
  };
}
