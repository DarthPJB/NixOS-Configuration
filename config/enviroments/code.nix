{ config, pkgs, ... }: 

{
fonts.fonts = with pkgs; [
	atom
	gpp
	emscripten
	stdenv-linux
];
}
