{ config, pkgs, ... }: 

{
enviroment.systemPackages = with pkgs; [
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
