{ config, pkgs, ... }:
{
	environment.systemPackages = with pkgs; [
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
