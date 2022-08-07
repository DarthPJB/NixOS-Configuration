{ config, pkgs, ... }:

{
    environment.systemPackages = [
      pkgs.slic3r
      pkgs.platformio
    ];
}