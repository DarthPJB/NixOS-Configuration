{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.element-desktop
  ];
}
