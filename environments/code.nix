{ config, lib, pkgs, unstable, ... }:

{
  environment.shellAliases = {
    code = "lite-xl .&";
  };
  environment.systemPackages = with pkgs; [
    pkgs.gpp
    pkgs.entr
    #pkgs.emscripten
    #pkgs.pulsar
    #pkgs.upterm
    #pkgs.platformio
    #pkgs.cool-retro-term
    pkgs.nix-top
    pkgs.lite-xl
    pkgs.neovim
    pkgs.progress
    pkgs.dnsutils
    pkgs.openssl
    pkgs.tmate
    pkgs.terminator
    pkgs.enlightenment.terminology
    pkgs.conky
    pkgs.cmatrix
    pkgs.nms
    pkgs.chafa
    pkgs.lolcat
    pkgs.figlet
    pkgs.cowsay
    pkgs.nmap
    pkgs.tree
    pkgs.ripgrep
    pkgs.bubblewrap
    pkgs.inotify-tools
    pkgs.rsync
    pkgs.git
    unstable.opencode
  ];
}
