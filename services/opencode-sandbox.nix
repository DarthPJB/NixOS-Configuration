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
      if [ "$OPENCODE_DEBUG" = "1" ]; then set -x; fi
      # shellcheck disable=SC2215,SC2086,SC2012

      handle_exit() {
        if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Entering handle_exit"; fi
        if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): cd to SESSION_FULL"; fi
        cd "$SESSION_FULL"
        # shellcheck disable=SC2012
        if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: cd to SESSION_FULL complete: $(ls -la | head -3 || true)"; fi
        if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Checking git diff"; fi
        if git diff --quiet && git diff --cached --quiet; then
          echo "No changes to commit"
        else
          if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git add"; fi
          git add . >/dev/null 2>&1
          if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git add complete"; fi
          if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git commit"; fi
          git commit -q -m "OpenCode session: $PROJECT_NAME $TIMESTAMP" || echo "Commit failed"
          if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git commit complete"; fi
           if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git push"; fi
           git remote add origin-push file:///speed-storage/opencode || true
           git push origin-push HEAD:"$BRANCH_NAME" || git push origin-push HEAD:"$BRANCH_NAME"
           if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git push complete"; fi
        fi
        if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): rsync restore"; fi
        rsync -a "$SAVE_FULL"/ "$SESSION_FULL"/ >/dev/null 2>&1
        # shellcheck disable=SC2012
        if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: rsync restore complete: $(ls -la | head -3 || true)"; fi
        if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): rm SAVE_FULL"; fi
        rm -rf "$SAVE_FULL"
        if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: rm SAVE_FULL complete"; fi
      }

      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Setting trap"; fi
      trap handle_exit EXIT
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: Setting trap complete"; fi

      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Setting WORKING_DIR"; fi
      WORKING_DIR="$(pwd)"
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: Setting WORKING_DIR complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Setting SESSION_FULL"; fi
      SESSION_FULL="$WORKING_DIR"
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: Setting SESSION_FULL complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Setting TIMESTAMP"; fi
      TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: Setting TIMESTAMP complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Setting PROJECT_NAME"; fi
      PROJECT_NAME="$(basename "$WORKING_DIR" | sed 's/[^a-zA-Z0-9]/-/g')"
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: Setting PROJECT_NAME complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Setting BRANCH_NAME"; fi
      BRANCH_NAME="sandbox/$PROJECT_NAME/$TIMESTAMP"
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: Setting BRANCH_NAME complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Setting SAVE_FULL"; fi
      SAVE_FULL="/tmp/opencode-backup-$TIMESTAMP"
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: Setting SAVE_FULL complete"; fi

      # PRE: Backup and init orphan git
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): mkdir SAVE_FULL"; fi
      mkdir -p "$SAVE_FULL"
      # shellcheck disable=SC2012
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: mkdir SAVE_FULL complete: $(ls -la "$SAVE_FULL" | head -3 || true)"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): rsync backup"; fi
      rsync -a "$SESSION_FULL"/ "$SAVE_FULL"/
      # shellcheck disable=SC2012
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: rsync backup complete: $(ls -la "$SAVE_FULL" | head -3 || true)"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): cd SESSION_FULL"; fi
      cd "$SESSION_FULL"
      # shellcheck disable=SC2012
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: cd SESSION_FULL complete: $(ls -la | head -3 || true)"; fi
       if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git remote add and fetch"; fi
       git remote add origin-persistent file:///speed-storage/opencode
       git fetch origin-persistent main || git fetch origin-persistent master || git fetch origin-persistent HEAD
       if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git remote add and fetch complete"; fi
       if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git checkout orphan"; fi
       git checkout --orphan "$BRANCH_NAME" FETCH_HEAD >/dev/null 2>&1  # Use FETCH_HEAD
       if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git checkout orphan complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git rm"; fi
      git rm -rf . >/dev/null 2>&1 || true
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git rm complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git checkout FETCH_HEAD"; fi
      git checkout FETCH_HEAD -- . >/dev/null 2>&1
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git checkout FETCH_HEAD complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git add"; fi
      git add . >/dev/null 2>&1
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git add complete"; fi
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): git commit base"; fi
      git commit -q -m "base commit for $PROJECT_NAME $TIMESTAMP"
      if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: git commit base complete"; fi
      

            # Bubblewrap mounts
            # shellcheck disable=SC2086
            if [ "$OPENCODE_DEBUG" = "1" ]; then echo "DEBUG: $(basename "$0"): Launching bwrap with args: --ro-bind /nix/store /nix/store --bind /run /run --ro-bind /etc /etc --dev-bind /dev/null /dev/null --dev-bind /dev/random /dev/random --dev-bind /dev/urandom /dev/urandom --ro-bind /proc /proc --ro-bind /sys /sys --tmpfs /tmp --bind $WORKING_DIR /home/opencode-sandbox/work --bind $SESSION_FULL /speed-storage/opencode --bind /speed-storage/opencode/.opencode /home/opencode-sandbox/.config/opencode --unshare-all --share-net --uid 4000 --gid 4000 --chdir /home/opencode-sandbox/work --setenv HOME /home/opencode-sandbox --setenv PWD /home/opencode-sandbox/work --setenv PATH ${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.git pkgs.neovim unstable.opencode]} --dir /home/opencode-sandbox"; fi
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
               -- bash -c "cd /home/opencode-sandbox/work && if [ \"\$OPENCODE_DEBUG\" = \"1\" ]; then exec ${lib.getExe unstable.opencode} agent list; else exec ${lib.getExe unstable.opencode} \"\$@\"; fi" opencode "$@" ; bwrap_rc=$?; echo "DEBUG: bwrap rc: $bwrap_rc" >&2
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
