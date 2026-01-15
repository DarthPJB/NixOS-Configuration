{ config, lib, pkgs, unstable, ... }:

{
  imports = [
    ./opencode-wrapper.nix
  ];

  environment.shellAliases = {
    code = "lite-xl";
    opencode-session = "opencode-session";
    opencode-list-sessions = "git branch -a | grep 'opencode-session' || echo 'No OpenCode sessions found'";
    opencode-review-session = "git checkout";
    opencode-merge-session = "git merge --no-ff -m 'Merge OpenCode session'";
    opencode-diff-session = "git diff main..";
    opencode-audit-all = "git branch -a | grep 'opencode-session' | xargs -I {} sh -c 'echo \"Branch: {}\"; git log --oneline -1 {}'";
    opencode-merge-all-approved = "git branch -a | grep 'opencode-session' | xargs -I {} git merge {} --no-ff -m 'Batch merge approved OpenCode session {}'";
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
    ((import config._module.args.sl) { inherit pkgs; })
  ];
}