{ config, lib, ... }:
{
  services.prometheus = {
    exporters.postgres = {
      enable = true;
      port = 3110;
    };
  };
  services = {
    postgresql = {
      enable =  true;
      enableTCPIP = true;
      dataDir = "/bulk-storage/postgres/${config.services.postgresql.package.psqlSchema}";
      authentication = ''
        local all all trust
        host all all 10.88.127.88/32 trust
        host all all 10.88.128.88/32 trust
      '';
      ensureUsers = [
        {
          name = "litellm";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = [
        "litellm"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 5432 ];

  systemd.services.fix-postgres-permissions = {
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Make sure that /postgres is owned by/accessible to the postgres user
      mkdir -p /bulk-storage/postgres
      chown postgres /bulk-storage/postgres
    '';
    requiredBy = [ "postgresql.service" ];
  };

}
