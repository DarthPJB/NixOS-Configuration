{ config, pkgs, ... }:

{
    programs.bash.shellAliases = {
  code = "lite-xl";
};
  environment.systemPackages = with pkgs; [
    pkgs.gpp
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
    (import
      (fetchFromGitHub {
        owner = "pinktrink";
        repo = "sl";
        rev = "a613b55b692304f8e020af8889ff996c0918fa7d";
        sha256 = "sha256-xH1oXNTwsOvIKv3XhP6Riqp2FtfncyMDOWSAgVRpkT8=";
      })
      { inherit pkgs; })
  ];
}
