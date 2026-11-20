{ config
, lib
, pkgs
, ...
}:

{
  environment.shellAliases = {
    code = "lite-xl .&";
  };
  environment.systemPackages = with pkgs; [
    pkgs.claude-code
    pkgs.cursor-cli
    pkgs.gpp
    pkgs.git-lfs
    pkgs.entr
    glab
    gh
    #pkgs.emscripten
    #pkgs.pulsar
    #pkgs.upterm
    pkgs.platformio
    #pkgs.cool-retro-term
    pkgs.nix-top
    pkgs.lite-xl
    pkgs.neovim
    pkgs.progress
    pkgs.dnsutils
    pkgs.openssl
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
  ]
  # tmate is marked insecure on nixpkgs_unstable (unpatched since 2022);
  # the refusal lives in outPath evaluation, so probe that depth. Install
  # only where the pin permits evaluation.
  ++ lib.optional (builtins.tryEval pkgs.tmate.outPath).success pkgs.tmate;
}
