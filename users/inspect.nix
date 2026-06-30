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
    # No extraGroups — no sudo, no wheel, no privileged access
  };

  services.openssh = {
    extraConfig = ''
      Match LocalPort 1108 User inspect Address 10.88.127.0/24
        PermitRootLogin no
        PasswordAuthentication no
    '';
  };

  systemd.tmpfiles.rules = [
    "d /tmp/inspect 0755 inspect inspect -"
    "Z /tmp/inspect 0755 inspect inspect - -"
  ];
}
