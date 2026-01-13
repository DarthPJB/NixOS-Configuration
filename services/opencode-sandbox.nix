{ config, lib, pkgs, unstable, ... }:

with lib;

let
  opencodeWrapper = pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      git
      neovim
      rsync
      diffutils
      bubblewrap
    ];

    text = ''
            set -e
      # shellcheck disable=SC2215

      handle_exit() {
        cd /speed-storage/opencode
        git stash push -m "opencode-temp" || true
        git checkout main || git checkout master
        git checkout -b "$BRANCH_NAME"
        rm -rf -- * .git
        rsync -a "$SESSION_FULL"/ .
        if ! diff -rq "$SAVE_FULL" "$SESSION_FULL"; then git add .; git commit -m "OpenCode config: $PROJECT_NAME $TIMESTAMP"; fi
        git checkout main
        git stash pop || true
        echo "Config branch: $BRANCH_NAME"
        # No project git ops.
      }

      trap handle_exit EXIT

      WORKING_DIR="$(pwd)"
      SESSION_FULL="$WORKING_DIR"








      

            # Bubblewrap mounts
            ${pkgs.bubblewrap}/bin/bwrap \
              --ro-bind /nix/store /nix/store \
              --bind /run /run \
              --ro-bind /etc /etc \
              --dev-bind /dev/null /dev/null \
              --dev-bind /dev/random /dev/random \
              --dev-bind /dev/urandom /dev/urandom \
              --ro-bind /proc /proc \
              --ro-bind /sys /sys \
              --tmpfs /tmp \
              --bind "$WORKING_DIR" /home/opencode-sandbox/work \
              --bind "$SESSION_FULL" /speed-storage/opencode \
              --bind /speed-storage/opencode/.opencode /home/opencode-sandbox/.config/opencode \
              --unshare-all \
              --share-net \
              --uid 4000 \
              --gid 4000 \
              --chdir /home/opencode-sandbox/work \
       --setenv HOME /home/opencode-sandbox \
       --setenv PWD /home/opencode-sandbox/work \
       --setenv PATH ${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.git pkgs.neovim unstable.opencode]} \
              --dir /home/opencode-sandbox \
               -- bash -c "cd /home/opencode-sandbox/work && exec ${lib.getExe unstable.opencode} \"\$@\"" opencode "$@"
    '';
  };

  opencodeUnwrapped = pkgs.writeShellApplication {
    name = "opencode-unwrapped";

    text = ''${lib.getExe unstable.opencode} "$@"'';
  };

in
{
  environment.systemPackages = [
    opencodeWrapper
    opencodeUnwrapped
  ];
}
