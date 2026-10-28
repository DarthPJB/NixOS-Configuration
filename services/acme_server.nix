{ fqdn
, dnsProvider ? "porkbun"
, secretName
, secretFile
, extraDomainNames ? [ ]
}:
{ config
, ...
}:
{
  users.groups.acme = { };

  # The secret is registered here so every machine importing this module gets
  # the provider-specific environment file. Multiple instances may reference
  # the same secret name and file; identical definitions merge cleanly.
  secrix.system.secrets.${secretName}.encrypted.file = secretFile;

  # Configure ACME appropriately
  security.acme.acceptTerms = true;
  security.acme.defaults = {
    # dnsProvider/environmentFile are deliberately NOT set here: remote-worker
    # imports this module once per provider, and differing defaults conflict.
    group = "acme";
    # Deterministic resolver for lego's CNAME/apex (zone) discovery; the
    # local dnsmasq on cortex-alpha serves static records for these zones.
    dnsResolver = "1.1.1.1:53";
    # Porkbun writes are not instantly visible on every authoritative server.
    dnsPropagationCheck = true;
  };

  # trigger the actual certificate generation for additional hostname
  security.acme.certs."${fqdn}" = {
    # dnsProvider MUST be set explicitly on the per-cert level.
    # The nixpkgs nginx module (commit 377c6bcefce8) sets
    # dnsProvider = mkOverride 2000 null for any enableACME vhost,
    # which overrides the inherited default from security.acme.defaults.
    # A plain assignment here (priority 100) beats mkOverride 2000.
    inherit dnsProvider extraDomainNames;
    environmentFile = config.secrix.system.secrets.${secretName}.decrypted.path;
    # webroot MUST be null when using dnsProvider — the ACME module asserts
    # exactly one of dnsProvider/webroot/listenHTTP/s3Bucket is non-null.
    webroot = null;
    group = "nginx";
  };
}
