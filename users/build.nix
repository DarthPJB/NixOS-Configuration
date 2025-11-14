{ config, pkgs, lib, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  #nix.settings.trusted-users = [ "build" ];
  users.users.build = {
    isNormalUser = true;
    uid = 1111;
    name = "build";
    description = "builder connection user";
    createHome = true;
    home = "/tmp/builder";
    openssh.authorizedKeys.keys = [ "${lib.readFile ../secrets/builder-key.pub}" ];
    extraGroups = [ /*No*/ ];
  };
  services.openssh.listenAddresses = [{
    addr = "10.88.127.${builtins.toString config.environment.vpn.postfix}";
    port = 22;
  }];
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ 22 ];
}

