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
		gimp-with-plugins
		digikam
		inkscape-with-extensions 
		lensfun
  	(blender.override { cudaSupport = true; })
		solvespace
		openscad
		(colmap.override { cudaSupport = true; })
		meshlab
		#freecad
		krita
	];
}
