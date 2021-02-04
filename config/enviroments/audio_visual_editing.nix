{ config, pkgs, ... }:

{
environment.systemPackages = with pkgs; [
	blender
	ffmpeg
	mplayer
	vlc
	kdenlive
	shotcut
];
}
