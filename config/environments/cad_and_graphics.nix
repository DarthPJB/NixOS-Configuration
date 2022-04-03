{ config, pkgs, ... }:


#let
#  baseconfig = { allowUnfree = true; };
#  unstableTarball =
#    fetchTarball
#      https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz;
#  unstable = import unstableTarball
#  {
#    config = baseconfig;
#  };
#in
{
	environment.systemPackages = with pkgs; [
		gimp
		inkscape
  	(blender.override { cudaSupport = true; })
		solvespace
		openscad
		colmapWithCuda
		#freecad
		krita
	];
}
