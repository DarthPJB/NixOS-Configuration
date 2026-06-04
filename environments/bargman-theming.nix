{ config
, pkgs
, bargman-assets
, ...
}:
let
  inherit (bargman-assets.packages.${pkgs.stdenv.hostPlatform.system})
    cursor-theme-bargman-cinematic
    plymouth-theme-boot
    plymouth-theme-shutdown
    ;
in
{
  environment.systemPackages = [
    cursor-theme-bargman-cinematic
  ];

  environment.sessionVariables = {
    XCURSOR_THEME = "BargmanCinematic-Cursors";
    XCURSOR_SIZE = "24";
  };

  boot.plymouth = {
    enable = true;
    theme = "plymouth-theme-boot";
    themePackages = [
      plymouth-theme-boot
      plymouth-theme-shutdown
    ];
  };
}
