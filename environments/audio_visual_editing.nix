{ config, pkgs, inputs, self, ... }:

{
  environment.systemPackages =
    let
      system = "x86_64-linux";
      pkgs_unstable = self.outputs.un_pkgs;
      services.gvfs.enable = true; # Mount, trash, and other functionalities
      services.tumbler.enable = true; # Thumbnail support for images
    in
    [
      pkgs_unstable.ffmpeg-full
      pkgs.mplayer
      pkgs.vlc
      pkgs.pcmanfm
      pkgs.ffmpegthumbnailer
      pkgs.kdenlive
      pkgs.shotcut
      pkgs.shutter
    ];
  programs = {
    thunar.enable = true;
  };
}
