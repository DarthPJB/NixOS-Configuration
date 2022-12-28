{ config, pkgs, ... }:

{
environment.systemPackages = with pkgs; [
	pkgs.gpp
	pkgs.emscripten
	pkgs.atom
	pkgs.vscode.fhs
	pkgs.neovim
	pkgs.dnsutils
	pkgs.openssl
	pkgs.upterm
	pkgs.tmux
	pkgs.cool-retro-term
	pkgs.terminator
        pkgs.enlightenment.terminology
        pkgs.platformio
];
}
