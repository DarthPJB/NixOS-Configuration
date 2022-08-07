{ config, pkgs, ... }:
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
		krita
	];
}
