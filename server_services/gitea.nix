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

  # ── Fabrication Forge branding ─────────────────────────────────────────────
  # Runtime asset layer: Gitea layers ${customDir}/public and
  # ${customDir}/templates over its built-in assets at startup. The tree is
  # built here and symlinked in whole (declarative, upgrade-safe).
  branding = pkgs.callPackage ./gitea-branding { };

  # ── Identity: LDAP (the fleet's OpenLDAP on cortex-alpha) ──────────────────
  # server_services/ldap.nix on cortex-alpha is the real, deployed directory
  # (LDAPS :636, dc=johnbargman,dc=net). Gitea authenticates against it with an
  # anonymous search bind + per-user bind: the directory's olcAccess already
  # grants `anonymous auth` on userPassword and `* read` elsewhere, so no shared
  # service credential exists or is required. Auth sources are DB rows, so the
  # source is reconciled declaratively by the oneshot below.
  ldap = {
    # Stable reconciliation key for `gitea admin auth` add/update.
    name = "johnbargman-ldap";
    host = "ldap.johnbargman.net";
    port = 636;
    userSearchBase = "dc=johnbargman,dc=net";
    userFilter = "(&(objectClass=inetOrgPerson)(uid=%s))";
  };

  provisionLdap = pkgs.writeShellApplication {
    name = "gitea-ldap-provision";
    runtimeInputs = [ pkgs.gitea pkgs.coreutils pkgs.gawk ];
    text = ''
      export GITEA_WORK_DIR=${stateDir}
      export GITEA_CUSTOM=${stateDir}/custom
      export HOME=${stateDir}
      GITEA_CONFIG=${confDir}/app.ini

      ID="$(${lib.getExe pkgs.gitea} --config "$GITEA_CONFIG" admin auth list \
        | ${lib.getExe pkgs.gawk} -v n="${ldap.name}" '$2==n {print $1; exit}')"

      ARGS=(
        --name "${ldap.name}"
        --security-protocol LDAPS
        --host "${ldap.host}"
        --port "${toString ldap.port}"
        --user-search-base "${ldap.userSearchBase}"
        --user-filter "${ldap.userFilter}"
        --username-attribute uid
        --firstname-attribute givenName
        --surname-attribute sn
        --email-attribute mail
      )

      if [ -z "$ID" ]; then
        ${lib.getExe pkgs.gitea} --config "$GITEA_CONFIG" admin auth add-ldap "''${ARGS[@]}"
      else
        ${lib.getExe pkgs.gitea} --config "$GITEA_CONFIG" admin auth update-ldap --id "$ID" "''${ARGS[@]}"
      fi
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

  # Reconcile the LDAP source to the declared state on every boot.
  systemd.services.gitea-ldap-provision = {
    description = "Provision LDAP authentication source for Gitea (OpenLDAP on cortex-alpha)";
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
      ExecStart = lib.getExe provisionLdap;
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

      # Fabrication Forge branding — the whole asset layer comes from the
      # store. Linked here instead of via tmpfiles: tmpfiles only runs at
      # boot, but branding must apply on every configuration switch.
      ${lib.getExe' pkgs.coreutils "rm"} -rf ${stateDir}/custom/public ${stateDir}/custom/templates
      ${lib.getExe' pkgs.coreutils "ln"} -s ${branding}/public ${stateDir}/custom/public
      ${lib.getExe' pkgs.coreutils "ln"} -s ${branding}/templates ${stateDir}/custom/templates
    '';
  };

  services.gitea = {
    enable = true;
    appName = "Fabrication Forge";
    stateDir = stateDir;
    # Database per the original spec: the fleet PostgreSQL (postgres.nix).
    # createDatabase (default) wires ensureDatabases/ensureUsers; the socket
    # default /run/postgresql matches postgres.nix's `local all all trust`.
    database = {
      type = "postgres";
      name = "gitea";
      user = "gitea";
    };
    lfs.enable = true;
    lfs.contentDir = "${stateDir}/lfs";
    minioAccessKeyId = secret "gitea-minio-access-key";
    minioSecretAccessKey = secret "gitea-minio-secret-key";
    settings = {
      server = {
        DOMAIN = "gitea.johnbargman.net";
        ROOT_URL = "https://gitea.johnbargman.net/";
        PUBLIC_URL_DETECTION = "auto";
        HTTP_ADDR = wgIp;
        HTTP_PORT = httpPort;
        # git+ssh on port 22 over WireGuard, served by the SYSTEM sshd
        # (server_services/git-ssh.nix owns the port-22 plane and auth policy).
        # Gitea's built-in SSH server is deliberately not used.
        DISABLE_SSH = false;
        START_SSH_SERVER = false;
        SSH_DOMAIN = "gitea.johnbargman.net";
        SSH_PORT = 22;
        # Published clone identity: git@gitea.johnbargman.net:owner/repo.git.
        # The `git` OS account is an entrypoint (see git-ssh.nix).
        SSH_USER = "git";
        LANDING_PAGE = "home";
      };
      service = {
        # Registration form disabled — accounts come from the directory.
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = false;
        SHOW_REGISTRATION_BUTTON = false;
        # The sign-in form is the transport for LDAP authentication (Gitea
        # looks the user up in the directory and binds with their password).
        # The previous static X-WEBAUTH-USER reverse-proxy header was an
        # unauthenticated identity (every WireGuard client collapsed into one
        # `wguser` account) and is gone. Break-glass stays on the `gitea admin`
        # CLI (gitea-create-admin).
        ENABLE_PASSWORD_SIGNIN_FORM = true;
        ENABLE_BASIC_AUTHENTICATION = false;
        ENABLE_PASSKEY_AUTHENTICATION = true;
        # Legacy OpenID 2.0 is not part of the identity path.
        ENABLE_OPENID_SIGNIN = false;
        ENABLE_REVERSE_PROXY_AUTHENTICATION = false;
        ENABLE_REVERSE_PROXY_AUTHENTICATION_API = false;
        ENABLE_REVERSE_PROXY_AUTO_REGISTRATION = false;
        ENABLE_REVERSE_PROXY_EMAIL = false;
      };
      # Identity is directory-owned: LDAP users cannot edit it inside Gitea.
      admin = {
        EXTERNAL_USER_DISABLE_FEATURES = "change_username,change_full_name,manage_credentials";
      };
      ui = {
        DEFAULT_THEME = "fabrication-forge";
        THEMES = "fabrication-forge,gitea-auto,gitea-light,gitea-dark";
        # File-tree glyphs: `basic` octicons inherit theme colours; the
        # default `material` set is off-brand for the forge.
        FILE_ICON_THEME = "basic";
        FOLDER_ICON_THEME = "basic";
        # `:forge:` renders the brand mark from assets/img/emoji/forge.png.
        CUSTOM_EMOJIS = "git,gitea,codeberg,gitlab,github,gogs,forge";
      };
      "ui.meta" = {
        AUTHOR = "Bargman-Tech";
        DESCRIPTION = "Fabrication Forge — private Git infrastructure for Bargman-Tech engineering.";
        KEYWORDS = "git,fabrication forge,bargman-tech,engineering";
      };
      other = {
        SHOW_FOOTER_VERSION = false;
        SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
        SHOW_FOOTER_POWERED_BY = false;
      };
      session.COOKIE_SECURE = true;
      security = {
        DISABLE_GIT_HOOKS = true;
        IMPORT_LOCAL_PATHS = false;
        PASSWORD_HASH_ALGO = "argon2";
        REVERSE_PROXY_TRUSTED_PROXIES = "10.88.127.1/32,10.88.128.1/32,10.88.127.50/32";
        # Restrict registration emails to internal domain
        EMAIL_DOMAIN_ALLOWLIST = "johnbargman.net";
        # Password hardening
        MIN_PASSWORD_LENGTH = 12;
        PASSWORD_COMPLEXITY = "upper,digit,spec";
        PASSWORD_CHECK_PWN = true;
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
