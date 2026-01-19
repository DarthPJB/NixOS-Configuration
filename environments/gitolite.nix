{ config, lib, pkgs, ... }:
{
  secrix.services.gitolite.secrets.admin.pub.encrypted.file = ../../secrets/git-admin.pub;

  users.users.git = {
    description = "Gitolite service user";
    isSystemUser = true;
    group = "git";
    home = "/bulk-storage/git-repos";
    shell = pkgs.gitolite;
    openssh.authorizedKeys.keyFiles = [ config.secrix.services.gitolite.secrets.admin.pub.decrypted.path ];
  };

  users.groups.git = { };

  systemd.tmpfiles.rules = [
    "d /bulk-storage/git-repos 0770 git git - -"
  ];

  environment.systemPackages = [ pkgs.gitolite ];

  services.openssh.extraConfig = ''
    Match User git
      PermitTTY no
      X11Forwarding no
      AllowAgentForwarding no
      AllowTcpForwarding no
      ForceCommand gitolite-shell pokej
  '';

  services.openssh.listenAddresses = [{
    addr = config.environment.vpn.wireg0.ips.[0];  # 10.88.127.3
    port = 22;
  }];
  networking.firewall.interfaces.wireg0.allowedTCPPorts = [ 22 ];
}
