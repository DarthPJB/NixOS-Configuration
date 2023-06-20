{ config, pkgs, inputs, ... }:

{
	environment.systemPackages = [
		pkgs_unstable.ffmpeg-full
		pkgs.mplayer
		pkgs.vlc
		pkgs.kdenlive
		pkgs.shotcut
		pkgs.shutter
	];
}
