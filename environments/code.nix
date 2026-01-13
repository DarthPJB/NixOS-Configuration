{ config, lib, pkgs, unstable, ... }:

{
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
    (import
      (fetchFromGitHub {
        owner = "pinktrink";
        repo = "sl";
        rev = "a613b55b692304f8e020af8889ff996c0918fa7d";
        sha256 = "sha256-xH1oXNTwsOvIKv3XhP6Riqp2FtfncyMDOWSAgVRpkT8=";
      })
      { inherit pkgs; })
  ] ++ lib.optionals config.services.opencode-sandbox.enable [ config.services.opencode-sandbox.opencodeShell config.services.opencode-sandbox.opencodeUnwrapped ];

  services.opencode-sandbox.enable = true;
}
