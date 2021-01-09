{ config, pkgs, ... }: 

{
fonts.fonts = with pkgs; [
	atom
	gpp
	emscripten
	emscriptenStdenv
	emscriptenPackages.zlib
];
}
