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
    Match LocalPort 22 User build Address 10.88.127.0/24
      PermitRootLogin no
      PasswordAuthentication = no

    Match LocalPort 22
      DenyUsers *
  '';

  services.openssh.listenAddresses = lib.mkIf (wgIp != null) [
    {
      addr = wgIp;
      port = 22;
    }
  ];

  networking.firewall.interfaces.wireg0.allowedTCPPorts = [ 22 ];
}
