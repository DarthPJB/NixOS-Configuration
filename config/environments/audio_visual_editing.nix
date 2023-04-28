{ config, pkgs, inputs, ... }:

{
	environment.systemPackages = 
	let
		system = "x86_64-linux";
		pkgs_unstable = import inputs.nixpkgs_unstable {
			inherit system;
			config.allowUnfree = true; 
		};

		#pkgs_unstable = inputs.nixpkgs_unstable.legacyPackages.x86_64-linux;
	in [
		# blender
		pkgs_unstable.ffmpeg-full
		pkgs.mplayer
		pkgs.vlc
		pkgs.kdenlive
		pkgs.shotcut
		pkgs.shutter
	];
}
