{ fqdn }: { pkgs, config, lib, ... }:
let
  inherit fqdn;
in
{
  users.groups.acme = { };

  /* trigger the actual certificate generation for additional hostname */
  security.acme.certs."${fqdn}" = {
    extraDomainNames = [ ]; #"johnbargman.com"];
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
