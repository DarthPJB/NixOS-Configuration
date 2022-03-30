{ config, pkgs, ... }:

{
environment.systemPackages = with pkgs; [
	pkgs.gpp
	pkgs.emscripten
	pkgs.emscriptenStdenv
	pkgs.emscriptenPackages.zlib
	pkgs.atom
	pkgs.cool-retro-term
	pkgs.terminator
	pkgs.enlightenment.terminology
	pkgs.neovim
];
}
