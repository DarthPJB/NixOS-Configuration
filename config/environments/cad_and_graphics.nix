{ config, pkgs,inputs, ... }:
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
		pkgs.digikam
		pkgs.inkscape-with-extensions 
		pkgs.lensfun
		pkgs.gimp-with-plugins
		(pkgs_unstable.blender.override { cudaSupport = true; })
		pkgs.solvespace
		pkgs.openscad
		(pkgs.colmap.override { cudaSupport = true; })
		pkgs.meshlab
		pkgs.krita
	];
}
