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