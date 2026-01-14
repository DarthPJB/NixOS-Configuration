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
        cd "$SESSION_FULL"
        if git diff --quiet && git diff --cached --quiet; then
          echo "No changes to commit"
        else
          git add . >/dev/null 2>&1
          git commit -q -m "OpenCode session: $PROJECT_NAME $TIMESTAMP" || echo "Commit failed"
          git push -q origin "$BRANCH_NAME" || echo "Push failed"
        fi
        rsync -a "$SAVE_FULL"/ "$SESSION_FULL"/ >/dev/null 2>&1
        rm -rf "$SAVE_FULL"
      }

      trap handle_exit EXIT

      WORKING_DIR="$(pwd)"
      SESSION_FULL="$WORKING_DIR"
      TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
      PROJECT_NAME="$(basename "$WORKING_DIR" | sed 's/[^a-zA-Z0-9]/-/g')"
      BRANCH_NAME="sandbox/$PROJECT_NAME/$TIMESTAMP"
      SAVE_FULL="/tmp/opencode-backup-$TIMESTAMP"

      # PRE: Backup and init orphan git
      mkdir -p "$SAVE_FULL"
      rsync -a "$SESSION_FULL"/ "$SAVE_FULL"/
      cd "$SESSION_FULL"
      git fetch --depth=1 origin main >/dev/null 2>&1 || git fetch --depth=1 origin master >/dev/null 2>&1
      git checkout --orphan "$BRANCH_NAME" >/dev/null 2>&1
      git rm -rf . >/dev/null 2>&1 || true
      git checkout FETCH_HEAD -- . >/dev/null 2>&1
      git add . >/dev/null 2>&1
      git commit -q -m "base commit for $PROJECT_NAME $TIMESTAMP"
      

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
