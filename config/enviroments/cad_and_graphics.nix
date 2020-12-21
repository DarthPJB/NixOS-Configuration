{ config, pkgs, ... }: 

{
fonts.fonts = with pkgs; [
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
