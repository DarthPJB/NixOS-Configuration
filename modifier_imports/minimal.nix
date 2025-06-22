{ config, pkgs,  ... }:
{

  # only add strictly necessary modules
  boot.initrd.includeDefaultModules = false;
  #boot.initrd.kernelModules = [ "ext4" ... ];


  # disable useless software
  environment.defaultPackages = [ ];
  xdg.icons.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;
}
