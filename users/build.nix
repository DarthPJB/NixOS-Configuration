{ config, pkgs, lib, ... }:
{
  users.users.build = {
    isNormalUser = true;
    uid = 1111;
    name = "build";
    description = "Remote Nix builder user";
    home = "/tmp/nix-builder-${toString config.users.users.build.uid}";
    createHome = true;
    openssh.authorizedKeys.keyFiles = [
      ../secrets/builder-key.pub
    ];
  };
  nix = {
    settings = {
      download-buffer-size = lib.mkDefault 524288000;
      #  max-jobs = lib.mkDefault 10;
      cores = lib.mkDefault 0;
    };
    #nrBuildUsers = lib.mkDefault 10;
  };
  services.openssh.extraConfig = ''
    Match User build
      PermitTTY no
      X11Forwarding no
      AllowAgentForwarding no
      AllowTcpForwarding no
  '';

  services.openssh.listenAddresses = [{
    addr = "10.88.127.${builtins.toString config.environment.vpn.postfix}";
    port = 22;
  }];

  networking.firewall.interfaces.wireg0.allowedTCPPorts = [ 22 ];
}

