{ config, lib, pkgs, unstable, ... }:

with lib;

let
  codeSandbox = pkgs.writeShellApplication {
    name = "code-sandbox";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      git
      neovim
      rsync
      diffutils
      bubblewrap
      patch
    ];

    text = ''
      set -e
      # shellcheck disable=SC2215

      # OPCODE_DEBUG flag
      if [ -n "$OPCODE_DEBUG" ]; then
        set -x
      fi

      # Var renames
      PROJECT_NAME="$1"
      TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
      BRANCH_NAME="opencode-$PROJECT_NAME-$TIMESTAMP"
      WORKING_DIR="$(pwd)"
      SESSION_FULL="$WORKING_DIR"
      SAVE_FULL="/tmp/opencode-session-$TIMESTAMP"

      # Orphan temp RW from RO base
      ORPHAN_DIR="/tmp/opencode-orphan-$TIMESTAMP"
      mkdir -p "$ORPHAN_DIR"

      # RW mounts: tree/config/work
      WORK_DIR="/home/sandbox_user/work"
      CONFIG_DIR="/home/sandbox_user/config"
      TREE_DIR="/home/sandbox_user/tree"

      # Patch trap
      handle_exit() {
        cd /speed-storage/opencode
        # Create patch from changes
        if [ -d "$SAVE_FULL" ]; then
          diff -ruN "$SAVE_FULL" "$SESSION_FULL" > "/tmp/$BRANCH_NAME.patch" || true
          # Apply patch to host branch
          git stash push -m "opencode-temp" || true
          git checkout main || git checkout master
          git checkout -b "$BRANCH_NAME"
          rm -rf -- * .git
          rsync -a "$SESSION_FULL"/ .
          if ! diff -rq "$SAVE_FULL" "$SESSION_FULL"; then
            git add .
            git commit -m "OpenCode config: $PROJECT_NAME $TIMESTAMP"
          fi
          git checkout main
          git stash pop || true
        fi
        echo "Config branch: $BRANCH_NAME"
        # Cleanup
        rm -rf "$ORPHAN_DIR" "$SAVE_FULL"
      }

      trap handle_exit EXIT

      # Copy initial state for patch
      mkdir -p "$SAVE_FULL"
      rsync -a "$SESSION_FULL"/ "$SAVE_FULL"/

      # Bubblewrap sandbox
      exec bwrap \
        --ro-bind /speed-storage/opencode /home/sandbox_user/tree \
        --bind "$SESSION_FULL" "$WORK_DIR" \
        --bind "$ORPHAN_DIR" "$CONFIG_DIR" \
        --tmpfs /tmp \
        --proc /proc \
        --dev /dev \
        --unshare-all \
        --uid 1000 \
        --gid 1000 \
        --setenv HOME /home/sandbox_user \
        --setenv USER sandbox_user \
        --chdir "$WORK_DIR" \
        -- ${lib.getExe unstable.opencode} "$@"
    '';
  };

  opencodeUnwrapped = pkgs.writeShellApplication {
    name = "opencode-unwrapped";

    text = ''${lib.getExe unstable.opencode} "$@"'';
  };

in
{
  environment.systemPackages = [
    codeSandbox
    opencodeUnwrapped
  ];
}