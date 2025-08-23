{ config, pkgs, self, ... }:
let
  fqdn = "johnbargman.net";
  certDir = config.security.acme.certs."${fqdn}".directory;
in
{
    networking.firewall.allowedTCPPorts = [ /*389*/ 636 ];
    secrix.services.openldap.secrets.ldap_master_password.encrypted.file = "${self}/secrets/ldap_master_password";
    services.openldap = {
    enable = true;

    /* enable plain and secure connections */
    urlList = [ "ldap:///" "ldaps:///" ];

    settings = {
      attrs = {
        olcLogLevel = "conns config";

        /* settings for acme ssl */
        olcTLSCACertificateFile = "${certDir}/full.pem";
        olcTLSCertificateFile = "${certDir}/cert.pem";
        olcTLSCertificateKeyFile = "${certDir}/key.pem";
        olcTLSCipherSuite = "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256";
        olcTLSCRLCheck = "none";
        olcTLSVerifyClient = "never";
        olcTLSProtocolMin = "3.3";
      };

      children = {
        "cn=schema".includes = [
          "${pkgs.openldap}/etc/schema/core.ldif"
          "${pkgs.openldap}/etc/schema/cosine.ldif"
          "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
        ];

        "olcDatabase={1}mdb".attrs = {
          objectClass = [ "olcDatabaseConfig" "olcMdbConfig" ];

          olcDatabase = "{1}mdb";
          olcDbDirectory = "/var/lib/openldap/data";

          olcSuffix = "dc=johnbargman,dc=net";

          /* your admin account, do not use writeText on a production system */
          olcRootDN = "cn=commander,dc=johnbargman,dc=net";
          olcRootPW.path = pkgs.writeText "olcRootPW" "pass";

          olcAccess = [
            /* custom access rules for userPassword attributes */
            ''{0}to attrs=userPassword
                by self write
                by anonymous auth
                by * none''

            /* allow read on anything else */
            ''{1}to *
                by * read''
          ];
        };
      };
    };
  };

  /* ensure openldap is launched after certificates are created */
  systemd.services.openldap = {
    wants = [ "acme-${fqdn}.service" ];
    after = [ "acme-${fqdn}.service" ];
  };
  users.users.openldap.extraGroups = [ "acme" "nginx" ];
  users.groups.acme.members = [ "openldap" ];
  }
