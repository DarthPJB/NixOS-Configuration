{ config
, pkgs
, lib
, ...
}:
{
  users.users.inspect = {
    isNormalUser = true;
    uid = 1112;
    name = "inspect";
    description = "Passive system inspection user — read-only, no sudo";
    createHome = true;
    home = "/tmp/inspect";
    openssh.authorizedKeys.keys = [
      "${lib.readFile ../secrets/public_keys/INSPECT_ED_25519.pub}"
    ];
    extraGroups = [ "systemd-journal" ]; # read-only journal access
  };

  services.openssh = {
    settings.AllowUsers = [ "inspect" ];
    extraConfig = ''
      Match LocalPort 1108 User inspect Address 10.88.127.0/24
        PermitRootLogin no
        PasswordAuthentication no
    '';
  };

  systemd.tmpfiles.rules = [
    "d /tmp/inspect 0755 inspect users -"
    "Z /tmp/inspect 0755 inspect users - -"
  ];
}
