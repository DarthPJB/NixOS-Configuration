{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.firefox
    pkgs.brave
    pkgs.vivaldi
  ];
}
