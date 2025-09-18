{ config, pkgs, ... }:

{
  environment.systemPackages = [
    # pkgs.slic3r - The best slicing software, with the best settings pannels - and best configuration. Now lost to time because "unmaintained" - perhaps perl5 is broken, not slicer?
    pkgs.orca-slicer
    pkgs.prusa-slicer
    pkgs.platformio
  ];
}
