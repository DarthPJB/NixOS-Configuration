{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pkgs.gpp
    pkgs.emscripten
    pkgs.pulsar
    pkgs.vscode
    pkgs.neovim
    pkgs.dnsutils
    pkgs.openssl
    pkgs.upterm
    pkgs.tmux
    pkgs.cool-retro-term
    pkgs.terminator
    pkgs.enlightenment.terminology
    pkgs.platformio
    pkgs.conky
    pkgs.sl
    pkgs.cmatrix
    pkgs.nms
    pkgs.chafa
    pkgs.lolcat
    pkgs.figlet
    pkgs.cowsay
    pkgs.nmap
    pkgs.tree
    pkgs.ripgrep
  ];
}
