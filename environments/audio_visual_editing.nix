{ config, pkgs, inputs, ... }:

{
  environment.systemPackages =
    let
      system = "x86_64-linux";
      pkgs_unstable = import inputs.nixpkgs_unstable {
        inherit system;
        config.allowUnfree = true;
      };
      services.gvfs.enable = true; # Mount, trash, and other functionalities
      services.tumbler.enable = true; # Thumbnail support for images
      #pkgs_unstable = inputs.nixpkgs_unstable.legacyPackages.x86_64-linux;
    in
    [
      # blender
      pkgs_unstable.ffmpeg-full
      pkgs.mplayer
      pkgs.vlc
      pkgs.pcmanfm
      pkgs.ffmpegthumbnailer
      pkgs.kdenlive
      #		pkgs.shotcut
      pkgs.shutter
    ];
}
