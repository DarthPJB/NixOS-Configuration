# Shared GitLab credentials module
# Import this on any machine that needs to fetch private GitLab flake inputs
# Uses secrix to decrypt the deploy token at runtime, injected via GIT_ASKPASS
{ config, lib, pkgs, self, ... }:
let
  # User-readable copy of the netrc (secrix decrypts root-only to /run/system-keys/)
  userNetrcPath = "/run/gitlab-netrc";

  # GIT_ASKPASS script — git invokes this with prompt text as $1
  # Reads username/password from the netrc file
  gitlabAskpass = pkgs.writeShellApplication {
    name = "gitlab-askpass";
    runtimeInputs = [ pkgs.gnused ];
    text = ''
      case "$1" in
        *Username*)
          exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login[[:space:]]*//p' "${userNetrcPath}"
          ;;
        *Password*)
          exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password[[:space:]]*//p' "${userNetrcPath}"
          ;;
      esac
    '';
  };
in
{
  # GitLab deploy token for private flake inputs
  # Encrypted with secrix — decrypted at boot to /run/system-keys/gitlab_netrc (root-only)
  secrix.system.secrets.gitlab_netrc = {
    encrypted.file = "${self}/secrets/ssh_deploy_keys/gitlab_netrc";
  };

  # Copy the netrc to a user-readable location after secrix decrypts it.
  # /run/system-keys/ is root-only; nix flake update runs as the user.
  systemd.services.gitlab-netrc-copy = {
    description = "Copy GitLab netrc to user-readable location";
    after = [ "secrix-system-secrets.service" ];
    before = [ "nix-daemon.service" ];
    requiredBy = [ "nix-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellApplication {
        name = "gitlab-netrc-copy";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          umask 022
          ${lib.getExe' pkgs.coreutils "cp"} /run/system-keys/gitlab_netrc "${userNetrcPath}"
          ${lib.getExe' pkgs.coreutils "chmod"} 0644 "${userNetrcPath}"
        '';
      }}/bin/gitlab-netrc-copy";
    };
  };

  # Provide git credentials via GIT_ASKPASS for all user sessions.
  # Git invokes GIT_ASKPASS when it needs credentials for https:// repos.
  # Nix passes through to git for flake input fetching, so this covers nix flake update.
  environment.sessionVariables.GIT_ASKPASS = "${gitlabAskpass}/bin/gitlab-askpass";

  # Point the nix daemon's netrc-file at the populated /run/gitlab-netrc.
  # Determinate Nix defaults this to /nix/var/determinate/netrc (empty).
  # The daemon needs its own netrc for git+https flake input fetching;
  # GIT_ASKPASS only covers user-session git, not the daemon.
  # gitlab-netrc-copy.service (Before=nix-daemon.service) ensures the file exists.
  nix.settings.netrc-file = userNetrcPath;
}
