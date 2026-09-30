# server_services/git-ssh.nix
#
# Port 22 = the WireGuard git-ssh plane.
#
# Git transport (Gitea now, legacy gitolite during migration) is served by the
# system sshd on port 22, bound ONLY to the WireGuard address. Human/admin SSH
# is separate (environments/sshd.nix, port 1108) and never shares this plane.
#
# Auth policy for the plane lives here; the git services only claim their OS
# account (gitolite -> `git`, Gitea -> `gitea`).
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
in
{
  services.openssh.extraConfig = ''
    # Only this block applies to connections on port 22 (git-ssh plane)
        Match LocalPort 22
          # Git service accounts only, from the VPN subnet.
          # Gitea serves git+ssh as `gitea`; gitolite (legacy cgit) as `git`.
          AllowUsers git@10.88.127.0/24 gitea@10.88.127.0/24

          # Explicitly reinforce (optional but clearer)
          PermitRootLogin no
          PasswordAuthentication no
  '';

  services.openssh.listenAddresses = lib.mkIf (wgIp != null) [
    {
      addr = wgIp;
      port = 22;
    }
  ];

  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ 22 ];
}
