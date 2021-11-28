{ config, pkgs, ... }:

{
environment.systemPackages = with pkgs; [
	atom
	gpp
	emscripten
	emscriptenStdenv
	emscriptenPackages.zlib
];
}
