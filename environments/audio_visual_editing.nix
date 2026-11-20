{ config
, pkgs
, lib
, self
, ...
}:

{
  environment.systemPackages = [
    pkgs.ffmpeg-full
    # Upstream nixpkgs swapped mplayer's libdvdnav_4_2_1 for modern libdvdnav
    # (the 4.2.1 fossil lacks dvdnav_open2, which the pin's ffmpeg_7
    # libavformat requires). Mirror the two-line fix until the pin carries it;
    # retire after the next nixpkgs bump. overrideAttrs, not override: the
    # stable surface's mplayer has no libdvdnav_4_2_1 argument to override —
    # and where the linked dvdnav is already modern this is a no-op.
    (pkgs.mplayer.overrideAttrs (old: {
      buildInputs = map (d: if lib.hasInfix "dvdnav" (d.name or "") then pkgs.libdvdnav else d) (old.buildInputs or [ ]);
    }))
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
