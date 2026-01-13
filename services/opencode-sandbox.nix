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
      SESSION_PROJECT="/tmp/session-project-$TIMESTAMP"
      BRANCH_NAME="$PROJECT_NAME-$TIMESTAMP"

      mkdir -p "$SESSION_PROJECT"; rsync -a --exclude='.git' "$WORKING_DIR/" "$SESSION_PROJECT"/
      SAVE_PROJECT="$SESSION_PROJECT-original"; cp -a "$SESSION_PROJECT" "$SAVE_PROJECT"

       SESSION_FULL="/tmp/session-full-$TIMESTAMP"
       rsync -a /speed-storage/opencode/ "$SESSION_FULL"/
       rm -rf "$SESSION_FULL"/.git

       SESSION_DOT="/tmp/session-dot-$TIMESTAMP"
       rsync -a "$SESSION_FULL"/.opencode/ "$SESSION_DOT"/
       rm -rf "$SESSION_DOT"/.git

       SAVE_ORIGINAL="$SESSION_FULL-original"; cp -a "$SESSION_FULL" "$SAVE_ORIGINAL"

        handle_exit() {
         cd /speed-storage/opencode
         git stash -m temp || true
         git checkout main || git checkout master
         git checkout -b "config-$BRANCH_NAME"
          rm -rf -- * .git
          rsync -a "$SESSION_FULL"/ .
         if ! diff -rq "$SAVE_ORIGINAL" "$SESSION_FULL"; then
           git add .
           git commit -m "OpenCode config: $PROJECT_NAME $TIMESTAMP"
         fi
         git checkout main
         git stash pop || true
         echo "Config branch: $BRANCH_NAME; Review: git log $BRANCH_NAME"
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
        --bind "$SESSION_PROJECT" /work \
        --bind "$SESSION_FULL" /speed-storage/opencode \
        --bind "$SESSION_FULL/.opencode" /home/opencode-sandbox/.config/opencode \
        --unshare-all \
        --share-net \
        --uid 4000 \
        --gid 4000 \
        --chdir /work \
        --setenv HOME /home/opencode-sandbox \
        --setenv PATH ${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.git pkgs.neovim unstable.opencode]} \
        --dir /home/opencode-sandbox \
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
