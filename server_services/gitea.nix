{ config
, pkgs
, lib
, ...
}:
let
  wgIp = "10.88.127.3";
  httpPort = 3000;
  minioEndpoint = "${wgIp}:2222";
  stateDir = "/bulk-storage/gitea";
  confDir = "${stateDir}/custom/conf";

  secret = name: config.secrix.system.secrets.${name}.decrypted.path;

  seedSecrets = pkgs.writeShellApplication {
    name = "gitea-seed-secrets";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${lib.getExe' pkgs.coreutils "mkdir"} -p ${confDir}
      ${lib.getExe' pkgs.coreutils "install"} -m 0400 ${secret "gitea-secret-key"} ${confDir}/secret_key
      ${lib.getExe' pkgs.coreutils "install"} -m 0400 ${secret "gitea-internal-token"} ${confDir}/internal_token
      ${lib.getExe' pkgs.coreutils "install"} -m 0400 ${secret "gitea-lfs-jwt-secret"} ${confDir}/lfs_jwt_secret
      ${lib.getExe' pkgs.coreutils "install"} -m 0400 ${secret "gitea-oauth2-jwt-secret"} ${confDir}/oauth2_jwt_secret
    '';
  };

  provisionMinio = pkgs.writeShellApplication {
    name = "gitea-minio-provision";
    runtimeInputs = [ pkgs.minio-client pkgs.coreutils ];
    text = ''
      root_user=""
      root_pass=""
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          MINIO_ROOT_USER=*) root_user="''${line#MINIO_ROOT_USER=}" ;;
          MINIO_ROOT_PASSWORD=*) root_pass="''${line#MINIO_ROOT_PASSWORD=}" ;;
        esac
      done < ${config.secrix.system.secrets.minio-rootCredentialsFile.decrypted.path}
      root_user="''${root_user%\"}"
      root_user="''${root_user#\"}"
      root_pass="''${root_pass%\"}"
      root_pass="''${root_pass#\"}"
      access=$(${lib.getExe' pkgs.coreutils "cat"} ${secret "gitea-minio-access-key"})
      secret_key=$(${lib.getExe' pkgs.coreutils "cat"} ${secret "gitea-minio-secret-key"})
      export MC_CONFIG_DIR=/run/gitea-minio-provision
      ${lib.getExe' pkgs.coreutils "mkdir"} -p "$MC_CONFIG_DIR"
      ${lib.getExe pkgs.minio-client} alias set gitealfs http://${minioEndpoint} "$root_user" "$root_pass" >/dev/null
      ${lib.getExe pkgs.minio-client} admin user add gitealfs "$access" "$secret_key" >/dev/null || true
      ${lib.getExe pkgs.minio-client} admin policy attach gitealfs readwrite --user "$access" >/dev/null || true
      ${lib.getExe pkgs.minio-client} mb --ignore-existing gitealfs/git-lfs >/dev/null
    '';
  };
in
{
  secrix.system.secrets = {
    gitea-secret-key = {
      encrypted.file = ../secrets/gitea-secret-key;
      decrypted = { user = "gitea"; group = "gitea"; mode = "0400"; };
    };
    gitea-internal-token = {
      encrypted.file = ../secrets/gitea-internal-token;
      decrypted = { user = "gitea"; group = "gitea"; mode = "0400"; };
    };
    gitea-lfs-jwt-secret = {
      encrypted.file = ../secrets/gitea-lfs-jwt-secret;
      decrypted = { user = "gitea"; group = "gitea"; mode = "0400"; };
    };
    gitea-oauth2-jwt-secret = {
      encrypted.file = ../secrets/gitea-oauth2-jwt-secret;
      decrypted = { user = "gitea"; group = "gitea"; mode = "0400"; };
    };
    gitea-minio-access-key = {
      encrypted.file = ../secrets/gitea-minio-access-key;
      decrypted = { user = "gitea"; group = "gitea"; mode = "0400"; };
    };
    gitea-minio-secret-key = {
      encrypted.file = ../secrets/gitea-minio-secret-key;
      decrypted = { user = "gitea"; group = "gitea"; mode = "0400"; };
    };
  };

  systemd.services.gitea-minio-provision = {
    description = "Provision MinIO user and git-lfs bucket for Gitea";
    after = [ "minio.service" ];
    wants = [ "minio.service" ];
    before = [ "gitea.service" ];
    requiredBy = [ "gitea.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "gitea-minio-provision";
      RuntimeDirectoryMode = "0700";
      ExecStart = lib.getExe provisionMinio;
    };
  };

  systemd.services.gitea = {
    after = [ "minio.service" "gitea-minio-provision.service" ];
    wants = [ "minio.service" ];
    requires = [ "gitea-minio-provision.service" ];
    unitConfig.RequiresMountsFor = [ stateDir ];
    preStart = lib.mkBefore ''
      ${lib.getExe seedSecrets}
    '';
  };

  services.gitea = {
    enable = true;
    stateDir = stateDir;
    lfs.enable = true;
    lfs.contentDir = "${stateDir}/lfs";
    minioAccessKeyId = secret "gitea-minio-access-key";
    minioSecretAccessKey = secret "gitea-minio-secret-key";
    settings = {
      server = {
        DOMAIN = "gitea.johnbargman.net";
        ROOT_URL = "https://gitea.johnbargman.net/";
        HTTP_ADDR = wgIp;
        HTTP_PORT = httpPort;
        DISABLE_SSH = true;
        LANDING_PAGE = "login";
      };
      service = {
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = true;
      };
      session.COOKIE_SECURE = true;
      security = {
        DISABLE_GIT_HOOKS = true;
        IMPORT_LOCAL_PATHS = false;
        PASSWORD_HASH_ALGO = "argon2";
        REVERSE_PROXY_TRUSTED_PROXIES = "10.88.127.1/32,10.88.128.1/32";
      };
      lfs = {
        STORAGE_TYPE = "minio";
        SERVE_DIRECT = false;
        MINIO_BASE_PATH = "lfs/";
      };
      storage = {
        STORAGE_TYPE = "minio";
        MINIO_ENDPOINT = minioEndpoint;
        MINIO_BUCKET = "git-lfs";
        MINIO_LOCATION = "homelab";
        MINIO_USE_SSL = false;
        SERVE_DIRECT = false;
      };
    };
  };

  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ httpPort ];
}
