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

#  services.monado = {
#    enable = true;
#    defaultRuntime = true; # Register as default OpenXR runtime
#  };
#  systemd.user.services.monado.environment = {
#    STEAMVR_LH_ENABLE = "1";
#    XRT_COMPOSITOR_COMPUTE = "1";
#  };
}
