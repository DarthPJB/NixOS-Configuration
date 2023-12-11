{ config, pkgs, ... }:
{
  environment.systemPackages =
    [
      pkgs.inkscape-with-extensions
      pkgs.lensfun
      pkgs.gimp-with-plugins
      pkgs.solvespace
      pkgs.openscad
      pkgs.meshlab
      pkgs.krita
    ];
}
