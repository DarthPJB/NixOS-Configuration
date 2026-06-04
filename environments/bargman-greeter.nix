{ config
, pkgs
, self
, bargman-assets
, ...
}:
let
  inherit (bargman-assets.packages.${pkgs.stdenv.hostPlatform.system})
    lightdm-theme-bargman-cinematic
    cursor-theme-bargman-cinematic
    ;
in
{
  imports = [
    ../modules/lightdm-webkit2-greeter.nix
  ];

  services.xserver.displayManager.lightdm = {
    enable = true;
    greeters.slick.enable = false;
    greeters.gtk.enable = false;
    greeters.webkit2 = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.lightdm-webkit2-greeter;
      theme = {
        package = lightdm-theme-bargman-cinematic;
        name = "bargman-cinematic";
      };
      cursorTheme = {
        package = cursor-theme-bargman-cinematic;
        name = "BargmanCinematic-Cursors";
        size = 24;
      };
      settings = {
        debug_mode = false;
        detect_theme_errors = false;
        screensaver_timeout = 300;
        secure_mode = true;
        time_format = "LT";
        time_language = "auto";
      };
    };
  };

  # Expose the lightdm-webkit2-greeter package so it can be built
  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.lightdm-webkit2-greeter
  ];
}
