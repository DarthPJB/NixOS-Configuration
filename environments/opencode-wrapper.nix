{ config, lib, pkgs, unstable, agentFiles, ... }:

with lib;

let
  hostAgentFiles = "/speed-storage/opencode";

  codeSandbox = pkgs.writeShellApplication {
    name = "opencode-boxed";
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
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then set -x; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Script starting"; fi

      handle_exit() {
        local TIMESTAMP="$TIMESTAMP"
        local PROJECT_NAME="$PROJECT_NAME"
        local BRANCH_NAME="$BRANCH_NAME"
        local ORPHAN_DIR="$ORPHAN_DIR"
        local HOST_AGENT_FILES="$HOST_AGENT_FILES"
        if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Entering trap"; fi
        if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting cd to orphan in trap"; fi
        cd "$ORPHAN_DIR/master"
        if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: cd complete"; fi
        if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Checking for changes with git diff"; fi
        git status --porcelain | grep -q . || echo "No changes"
        if ! git diff --quiet master; then
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: git diff complete, changes detected"; fi
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Generating patch"; fi
          git diff master > "/tmp/patch-$BRANCH_NAME.patch"
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: git diff for patch complete"; fi
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting cd to host"; fi
          cd "$HOST_AGENT_FILES"
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: cd complete"; fi
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Applying to host"; fi
          if ! git rev-parse --git-dir > /dev/null 2>&1; then echo "ERROR: Host not git"; exit 1; fi
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting git checkout"; fi
          git checkout -b "$BRANCH_NAME" || git switch -c "$BRANCH_NAME"
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: git checkout complete"; fi
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting git apply"; fi
          if git apply --index "/tmp/patch-$BRANCH_NAME.patch"; then
            if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: git apply complete"; fi
            git commit -m "Sandbox patch: $PROJECT_NAME $TIMESTAMP"
            git push -u origin "$BRANCH_NAME" || echo "Push failed"
          else
            echo "Patch apply failed"
          fi
          rm -f "/tmp/patch-$BRANCH_NAME.patch"
        else
          if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: git diff complete, no changes"; fi
          echo "No changes in orphan"
        fi
        if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Trap complete"; fi
      }

      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Setting variables"; fi
      current_working_dir="$(pwd)"
      agent_files_dir="${agentFiles}"
      TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
      PROJECT_NAME="$(basename "$current_working_dir" | sed 's/[^a-zA-Z0-9]/-/g')"
      BRANCH_NAME="sandbox/$PROJECT_NAME/$TIMESTAMP"
      ORPHAN_DIR="/tmp/agent-orphan-$TIMESTAMP"
      HOST_AGENT_FILES="/speed-storage/opencode"
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Vars set"; fi

      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Setting trap"; fi
      trap handle_exit EXIT
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Trap set"; fi

      # PRE: Backup and init orphan git from RO base
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting mkdir"; fi
      mkdir -p "$ORPHAN_DIR"
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: mkdir complete"; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Cloning RO base"; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting cd to ORPHAN_DIR"; fi
      cd "$ORPHAN_DIR"
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: cd complete"; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting git clone"; fi
       git -c safe.directory="$agent_files_dir/.git" clone --bare "$agent_files_dir" .  # Bare clone RO base
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: git clone complete"; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting git worktree"; fi
      git worktree add master  # RW master-only orphan tree
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: git worktree complete"; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting cd to master"; fi
      cd master
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: cd complete"; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting mkdir .config/opencode"; fi
      mkdir -p .config/opencode
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: mkdir complete"; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting rsync"; fi
      rsync -a "$agent_files_dir"/.opencode/ .config/opencode/  # Config subset
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: rsync complete"; fi
       if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Orphan ready"; fi

       uid=$(id -u)
       gid=$(id -g)

       # Bubblewrap mounts
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Launching bwrap"; fi
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: Starting bwrap exec"; fi
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
        --uid "$uid" \
        --gid "$gid" \
        --chdir /home/sandbox_user/work \
        --setenv HOME /home/sandbox_user \
        --setenv PWD /home/sandbox_user/work \
        --setenv PATH "${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.git pkgs.neovim unstable.opencode]}" \
        --dir /home/sandbox_user \
        -- bash -c "cd /home/sandbox_user/work && exec ${lib.getExe unstable.opencode} ''${OPCODE_DEBUG:+--log-level DEBUG --print-logs} \"\$@\"" -- "$@"
      if [ "''${OPCODE_DEBUG:-0}" = "1" ]; then echo "DEBUG: bwrap exec complete"; fi
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