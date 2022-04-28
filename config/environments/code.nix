{ config, pkgs, ... }:

{
environment.systemPackages = with pkgs; [
	pkgs.gpp
	pkgs.emscripten
	pkgs.atom
	pkgs.vscode
	pkgs.neovim
	pkgs.cool-retro-term
	pkgs.terminator
	pkgs.enlightenment.terminology
];
}
