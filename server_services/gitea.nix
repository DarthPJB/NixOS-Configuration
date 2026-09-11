{ config
, pkgs
, lib
, ...
}:
let
  wgIp = "10.88.127.3";
  httpPort = 3000;
  minioEndpoint = "${wgIp}:2222";
  credDir = "/run/gitea-minio";
  accessKeyFile = "${credDir}/access-key";
  secretKeyFile = "${credDir}/secret-key";
  minioEnvFile = config.secrix.system.secrets.minio-rootCredentialsFile.decrypted.path;

  extractMinioCreds = pkgs.writeShellApplication {
    name = "gitea-minio-creds";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      access=""
      secret=""
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          MINIO_ROOT_USER=*) access="''${line#MINIO_ROOT_USER=}" ;;
          MINIO_ROOT_PASSWORD=*) secret="''${line#MINIO_ROOT_PASSWORD=}" ;;
        esac
      done < '${minioEnvFile}'
      access="''${access%\"}"
      access="''${access#\"}"
      secret="''${secret%\"}"
      secret="''${secret#\"}"
      if [ -z "$access" ] || [ -z "$secret" ]; then
        echo "gitea-minio-creds: MINIO_ROOT_USER/PASSWORD missing" >&2
        exit 1
      fi
      ${lib.getExe' pkgs.coreutils "mkdir"} -p ${credDir}
      ${lib.getExe' pkgs.coreutils "install"} -m 0400 -o gitea -g gitea /dev/null ${accessKeyFile}
      ${lib.getExe' pkgs.coreutils "install"} -m 0400 -o gitea -g gitea /dev/null ${secretKeyFile}
      ${lib.getExe' pkgs.coreutils "printf"} '%s' "$access" > ${accessKeyFile}
      ${lib.getExe' pkgs.coreutils "printf"} '%s' "$secret" > ${secretKeyFile}
    '';
  };
in
{
  systemd.services.gitea-minio-creds = {
    description = "Extract MinIO credentials for Gitea LFS";
    after = [ "minio.service" ];
    wants = [ "minio.service" ];
    before = [ "gitea.service" ];
    requiredBy = [ "gitea.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe extractMinioCreds;
    };
  };

  systemd.services.gitea = {
    after = [ "minio.service" "gitea-minio-creds.service" ];
    wants = [ "minio.service" ];
    requires = [ "gitea-minio-creds.service" ];
    unitConfig.RequiresMountsFor = [ "/bulk-storage/gitea" ];
  };

  services.gitea = {
    enable = true;
    stateDir = "/bulk-storage/gitea";
    lfs.enable = true;
    lfs.contentDir = "/bulk-storage/gitea/lfs";
    minioAccessKeyId = accessKeyFile;
    minioSecretAccessKey = secretKeyFile;
    settings = {
      server = {
        DOMAIN = "gitea.johnbargman.net";
        ROOT_URL = "https://gitea.johnbargman.net/";
        HTTP_ADDR = wgIp;
        HTTP_PORT = httpPort;
        DISABLE_SSH = true;
      };
      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
      lfs.STORAGE_TYPE = "minio";
      storage = {
        STORAGE_TYPE = "minio";
        MINIO_ENDPOINT = minioEndpoint;
        MINIO_BUCKET = "git-lfs";
        MINIO_LOCATION = "homelab";
        MINIO_USE_SSL = false;
      };
    };
  };

  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ httpPort ];
}
