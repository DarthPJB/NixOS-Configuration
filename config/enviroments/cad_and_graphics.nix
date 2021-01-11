{ config, pkgs, ... }:

{
environment.systemPackages = with pkgs; [
	gimp
	inkscape
	blender
	solvespace
	openscad
	freecad
	krita
	tiled
];
}
