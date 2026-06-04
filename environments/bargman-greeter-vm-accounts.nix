{ pkgs, ... }:

{
  users.users.test = {
    isNormalUser = true;
    password = "test";
    uid = 1000;
    extraGroups = [ "wheel" ];
  };

  users.groups.test = { };
}
