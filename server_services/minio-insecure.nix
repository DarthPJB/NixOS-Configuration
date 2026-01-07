{ pkgs, config, ... }:
let
  host-address = "10.88.127.3";
  host-port = 2222;
  console-port = 2223;
  toAddress = p: "${host-address}:${toString p}";
in
{
  secrix.system.secrets.minio-rootCredentialsFile = {
    encrypted.file = ../secrets/minio-rootCredentialsFile;
    decrypted = {
      user = "minio";
      group = "minio";
      mode = "0400";
    };
  };

  services = {
    minio = {
      browser = false;
      enable = true;
      region = "homelab";
      listenAddress = toAddress host-port;
      consoleAddress = toAddress console-port;
      dataDir = [ "/bulk-storage/minio" ];
      rootCredentialsFile = config.secrix.system.secrets.minio-rootCredentialsFile.decrypted.path;
    };
  };
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ host-port console-port ];
  systemd.services.minio.environment.MINIO_PROMETHEUS_AUTH_TYPE = "public";
}
