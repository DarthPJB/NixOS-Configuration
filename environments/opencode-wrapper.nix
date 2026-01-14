{ config, lib, pkgs, unstable, agentFiles, ... }:

with lib;

let
  hostAgentFiles = "/speed-storage/opencode";

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
      if [ "$OPCODE_DEBUG" = "1 = "1" ]; then set -x; fi

      handle_exit() {
        if [ "$OPCODE_DEBUG" = "1" ]; then echo "DEBUG: Entering trap"; fi
        cd "$ORPHAN_DIR/master"
        if ! git diff --quiet master; then
          if [ "$OPCODE_DEBUG" = "1" ]; then echo "DEBUG: Generating patch"; fi
          git diff master > "/tmp/patch-$BRANCH_NAME.patch"
          cd "$HOST_AGENT_FILES"
          if [ "$OPCODE_DEBUG" = "1" ]; then echo "DEBUG: Applying to host"; fi
          git checkout -b "$BRANCH_NAME" || git switch -c "$BRANCH_NAME"
          git add .
          if git apply "/tmp/patch-$BRANCH_NAME.patch"; then
            git commit -m "Sandbox patch: $PROJECT_NAME $TIMESTAMP"
            git push -u origin "$BRANCH_NAME" || echo "Push failed"
          else
            echo "Patch apply failed"
          fi
          rm -f "/tmp/patch-$BRANCH_NAME.patch"
        else
          echo "No changes in orphan"
        fi
        rm -rf "$ORPHAN_DIR"
        if [ "$OPCODE_DEBUG" = "1" ]; then echo "DEBUG: Trap complete"; fi
      }

      trap handle_exit EXIT

      current_working_dir="$(pwd)"
      agent_files_dir="${agentFiles}"
      TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
      PROJECT_NAME="$(basename "$current_working_dir" | sed 's/[^a-zA-Z0-9]/-/g')"
      BRANCH_NAME="sandbox/$PROJECT_NAME/$TIMESTAMP"
      SAVE_FULL="/tmp/opencode-backup-$TIMESTAMP"
      ORPHAN_DIR="/tmp/agent-orphan-$TIMESTAMP"
      HOST_AGENT_FILES="/speed-storage/opencode"

      if [ "$OPCODE_DEBUG" = "1" ]; then echo "DEBUG: Vars set"; fi

      # PRE: Backup and init orphan git from RO base
      mkdir -p "$ORPHAN_DIR"
      if [ "$OPCODE_DEBUG" = "1" ]; then echo "DEBUG: Cloning RO base"; fi
      cd "$ORPHAN_DIR"
      git clone --bare "$agent_files_dir" .  # Bare clone RO base
      git worktree add master  # RW master-only orphan tree
      cd master
      mkdir -p .config/opencode
      rsync -a "$agent_files_dir"/.opencode/ .config/opencode/ 2>/dev/null || true  # Config subset
      if [ "$OPCODE_DEBUG" = "1" ]; then echo "DEBUG: Orphan ready"; fi

      # Bubblewrap mounts
      if [ "$OPCODE_DEBUG" = "1" ]; then echo "DEBUG: Launching bwrap"; fi
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
        --bind "$ORPHAN_DIR/master" /speed-storage/opencode \
        --bind "$ORPHAN_DIR/master/.config/opencode" /home/sandbox_user/.config/opencode \
        --bind "$current_working_dir" /home/sandbox_user/work \
        --unshare-all \
        --share-net \
        --uid 4000 \
        --gid 4000 \
        --chdir /home/sandbox_user/work \
        --setenv HOME /home/sandbox_user \
        --setenv PWD /home/sandbox_user/work \
        --setenv PATH ${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.git pkgs.neovim unstable.opencode]} \
        --dir /home/sandbox_user \
        -- bash -c "cd /home/sandbox_user/work && exec ${lib.getExe unstable.opencode} ${OPENCODE_DEBUG:+--log-level DEBUG --print-logs} \"\$@\"" opencode \"\$@\"
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