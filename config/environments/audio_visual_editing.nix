{ config, pkgs, ... }:

{
environment.systemPackages = with pkgs; [
	# blender
	ffmpeg-full
	mplayer
	vlc
	kdenlive
	shotcut
	shutter
];
}
