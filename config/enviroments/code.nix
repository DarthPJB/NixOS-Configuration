{ config, pkgs, ... }: 

{
enviroment.systemPackages = with pkgs; [
	atom
	gpp
	emscripten
	emscriptenStdenv
	emscriptenPackages.zlib
];
}
