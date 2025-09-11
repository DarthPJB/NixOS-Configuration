{ config, pkgs, self, ... }:

{
  environment.systemPackages =
    [
      pkgs.ffmpeg-full
      pkgs.mplayer
      pkgs.vlc
      pkgs.pcmanfm
      pkgs.ffmpegthumbnailer
      pkgs.kdePackages.kdenlive
      pkgs.shotcut
      pkgs.shutter
    ];
  services.gvfs.enable = true; # Mount, trash, and other functionalities
  services.tumbler.enable = true; # Thumbnail support for images
  programs = {
    thunar.enable = true;
  };
}
