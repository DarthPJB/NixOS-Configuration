{ config, lib, pkgs, unstable, ... }:

with lib;

let
  cfg = config.services.opencode-sandbox;

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

      WORKING_DIR="$(pwd)"
      PROJECT_NAME=$(basename "$WORKING_DIR")
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      SESSION_DIR="/tmp/session-$TIMESTAMP-agents"
      BRANCH_NAME="$PROJECT_NAME-$TIMESTAMP"

      mkdir -p "$SESSION_DIR"
      rsync -a /var/lib/opencode/ "$SESSION_DIR"/
      rm -rf "$SESSION_DIR"/.git

      SAVE_ORIGINAL="$SESSION_DIR-original"
      cp -a /var/lib/opencode "$SAVE_ORIGINAL"

      handle_exit() {
        cd /var/lib/opencode
        git checkout -b "$PROJECT_NAME-$TIMESTAMP" || git checkout -b "$BRANCH_NAME"
        rm -rf -- * .git
        rsync -a "$SESSION_DIR"/ .
        if ! diff -rq "$SAVE_ORIGINAL" "$SESSION_DIR"; then
          git add .
          git commit -m "OpenCode: $PROJECT_NAME $TIMESTAMP"
          echo "Review/merge cmds"
        fi
      }

      trap 'handle_exit' EXIT

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
        --bind "$SESSION_DIR" /var/lib/opencode \
        --bind "$SESSION_DIR" /speed-storage/opencode \
        --bind "$WORKING_DIR" /work \
        --unshare-all \
        --share-net \
        --uid "$(id -u)" \
        --gid "$(id -g)" \
        --chdir /work \
        --setenv HOME /home/user \
        --setenv PATH ${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.git pkgs.neovim unstable.opencode]} \
        --dir /home/user \
        -- bash -c "ls /nix/store/*opencode 2>/dev/null || echo NO OPENCODE; echo PATH=\$PATH; cd /work && exec \${lib.getExe unstable.opencode}"
    '';
  };

  opencodeUnwrapped = pkgs.writeShellApplication {
    name = "opencode-unwrapped";

    text = ''${lib.getExe unstable.opencode} "$@"'';
  };

in
{
  options.services.opencode-sandbox = {
    enable = mkEnableOption "OpenCode sandbox wrapper";

    workingDir = mkOption {
      type = types.str;
      default = "/home/pokej/NixOS-Configuration";
      description = "Default working directory (if PWD is invalid)";
    };

    speedStorage = mkOption {
      type = types.bool;
      default = true;
      description = "Mount /var/lib/opencode if available";
    };

    opencodeShell = mkOption {
      type = types.package;
      description = "OpenCode sandbox shell wrapper";
    };

    opencodeUnwrapped = mkOption {
      type = types.package;
      description = "OpenCode unwrapped launcher";
    };
  };

  config = mkIf cfg.enable {
    services.opencode-sandbox.opencodeShell = opencodeWrapper;
    services.opencode-sandbox.opencodeUnwrapped = opencodeUnwrapped;
    environment.systemPackages = [
      opencodeWrapper
      opencodeUnwrapped
    ];
  };
}
