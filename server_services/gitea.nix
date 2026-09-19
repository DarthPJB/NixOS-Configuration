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

  # nixpkgs minio-client execs getent at runtime and does not wrap it.
  mc = pkgs.symlinkJoin {
    name = "mc-with-getent";
    paths = [ pkgs.minio-client ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/mc --prefix PATH : ${lib.makeBinPath [ pkgs.unixtools.getent pkgs.coreutils ]}
    '';
  };

  provisionMinio = pkgs.writeShellApplication {
    name = "gitea-minio-provision";
    runtimeInputs = [ mc pkgs.coreutils pkgs.unixtools.getent ];
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
      export HOME="$MC_CONFIG_DIR"
      ${lib.getExe' pkgs.coreutils "mkdir"} -p "$MC_CONFIG_DIR"
      ${lib.getExe' mc "mc"} alias set gitealfs http://${minioEndpoint} "$root_user" "$root_pass" >/dev/null
      ${lib.getExe' mc "mc"} admin user add gitealfs "$access" "$secret_key" >/dev/null || true
      ${lib.getExe' mc "mc"} admin policy attach gitealfs readwrite --user "$access" >/dev/null || true
      ${lib.getExe' mc "mc"} mb --ignore-existing gitealfs/git-lfs >/dev/null
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
    gitea-admin-password = {
      encrypted.file = ../secrets/gitea-admin-password;
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

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 gitea gitea -"
    "d ${stateDir}/custom 0750 gitea gitea -"
    "d ${confDir} 0750 gitea gitea -"
    "Z ${stateDir}/custom 0750 gitea gitea -"
  ];

  systemd.services.gitea = {
    after = [ "minio.service" "gitea-minio-provision.service" ];
    wants = [ "minio.service" ];
    requires = [ "gitea-minio-provision.service" ];
    # stateDir is a directory on the pool, not its own mount.
    unitConfig.RequiresMountsFor = [ "/bulk-storage" ];
    # nixpkgs sets ProtectHome=true; HOME is stateDir, so preStart cannot mkdir.
    serviceConfig.ProtectHome = lib.mkForce false;
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
        # Inherit MINIO_* from [storage]. Setting STORAGE_TYPE here blanks the endpoint.
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

  # Declarative admin user — created on first boot, idempotent on subsequent boots.
  systemd.services.gitea-create-admin = {
    description = "Create Gitea admin user";
    after = [ "gitea.service" ];
    requires = [ "gitea.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "gitea";
      Group = "gitea";
      WorkingDirectory = stateDir;
      Environment = [
        "GITEA_WORK_DIR=${stateDir}"
        "GITEA_CUSTOM=${stateDir}/custom"
        "HOME=${stateDir}"
      ];
    };
    path = [ pkgs.gitea ];
    script = ''
      set -euo pipefail
      ADMIN_USER="John88"
      ADMIN_EMAIL="john@johnbargman.net"
      ADMIN_PASS=$(${lib.getExe' pkgs.coreutils "cat"} ${secret "gitea-admin-password"})
      GITEA_CONFIG=${confDir}/app.ini

      # Skip if admin already exists
      if gitea --config "$GITEA_CONFIG" admin user list 2>/dev/null | grep -q "$ADMIN_USER"; then
        echo "Admin user '$ADMIN_USER' already exists, skipping."
        exit 0
      fi

      gitea --config "$GITEA_CONFIG" admin user create \
        --admin \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASS" \
        --email "$ADMIN_EMAIL" \
        --must-change-password=false
      echo "Created admin user '$ADMIN_USER'."
    '';
  };
}
