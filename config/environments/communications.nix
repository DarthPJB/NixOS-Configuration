{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.element-desktop
    pkgs.discord
    pkgs.thunderbird
  ];
}
