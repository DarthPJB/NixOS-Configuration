{ pkgs, config, ... }:
let
  host-address = "10.88.127.3";
  host-port = 2222;
  console-port = 80;
  toAddress = p: "${host-address}:${toString p}";
in
{
  secrix.services.minio.secrets.minio-rootCredentialsFile.encrypted.file = ../secrets/minio-rootCredentialsFile;

  services = {

    minio = {
      enable = true;
      region = "homelab";
      listenAddress = toAddress host-port;
      consoleAddress = toAddress console-port;
      dataDir = [ "/bulk-storage/minio" ];
      rootCredentialsFile = config.secrix.services.minio.secrets.minio-rootCredentialsFile.decrypted.path;
    };
  };

  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ host-port console-port ];
}
