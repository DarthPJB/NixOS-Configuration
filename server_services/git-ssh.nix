# server_services/git-ssh.nix
#
# Port 22 = the WireGuard git-ssh plane.
#
# Git transport (Gitea now, legacy gitolite during migration) is served by the
# system sshd on port 22, bound ONLY to the WireGuard address. Human/admin SSH
# is separate (environments/sshd.nix, port 1108) and never shares this plane.
#
# Auth policy for the plane lives here. `git` is the published clone identity
# (Gitea SSH_USER): it is an entrypoint account only — sshd authenticates
# against Gitea's authorized_keys and the forced command is re-executed as the
# `gitea` service account, which owns the data directory and database.
# Legacy gitolite/cgit is retired (removed 2026-10-01).
{ config
, pkgs
, lib
, ...
}:
let
  wgIp =
    if config.enableWgTopology.machineIp or null != null then
      config.enableWgTopology.machineIp
    else if config.environment ? vpn && config.environment.vpn.enable then
      "10.88.127.${builtins.toString config.environment.vpn.postfix}"
    else
      null;

  # Login shell for `git`: sshd runs it as "<shell> -c '<authorized_keys
  # command>'". Forward exactly that forced command to the gitea service
  # user; refuse everything else. No shell access of its own.
  gitEntrypoint = (pkgs.writeShellApplication {
    name = "git-ssh-entrypoint";
    runtimeInputs = [ pkgs.sudo pkgs.bash ];
    text = ''
      if [ "''${1-}" = "-c" ] && [ -n "''${2-}" ]; then
        exec ${lib.getExe pkgs.sudo} -u gitea -- ${lib.getExe' pkgs.bash "bash"} -c "$2"
      fi
      echo "git-ssh-entrypoint: shell access is not provided" >&2
      exit 1
    '';
  }) // {
    # users.users.<n>.shell requires a shell package (types.shellPackage).
    shellPath = "/bin/git-ssh-entrypoint";
  };
in
{
  services.openssh.extraConfig = ''
    # Only this block applies to connections on port 22 (git-ssh plane)
        Match LocalPort 22
          # Git service accounts only, from the VPN subnet. `git` is the
          # published clone identity (Gitea SSH_USER); `gitea` is the service
          # account and remains a valid direct path.
          AllowUsers git@10.88.127.0/24 gitea@10.88.127.0/24

          # Explicitly reinforce (optional but clearer)
          PermitRootLogin no
          PasswordAuthentication no

        # `git` authenticates against Gitea's authorized_keys (same file the
        # service writes); its login shell re-execs the forced command as
        # `gitea` via the sudo rule below.
        Match LocalPort 22 User git
          AuthorizedKeysFile /bulk-storage/gitea/.ssh/authorized_keys
          PermitRootLogin no
          PasswordAuthentication no
  '';

  users.groups.git = { };
  users.users.git = {
    isSystemUser = true;
    group = "git";
    description = "Gitea git+ssh entrypoint (port 22 plane)";
    shell = gitEntrypoint;
  };

  # The entrypoint may run exactly one thing as the service account: gitea's
  # own serv handler — the forced command Gitea writes into authorized_keys.
  security.sudo.extraRules = [
    {
      users = [ "git" ];
      commands = [
        {
          command = "${lib.getExe' pkgs.bash "bash"} -c ${lib.getExe pkgs.gitea}*";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  services.openssh.listenAddresses = lib.mkIf (wgIp != null) [
    {
      addr = wgIp;
      port = 22;
    }
  ];

  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ 22 ];
}
