{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.opencode-sandbox;

  sessionScript = pkgs.writeScriptBin "opencode-session" ''
    #!/bin/bash
    set -e

    WORKING_DIR="${cfg.workingDir}"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    PID=$$
    BRANCH_NAME="opencode-session-$TIMESTAMP-$PID"
    TEMP_DIR="/tmp/opencode-session-$PID"

    # Pre-sync: copy directory to temp
    mkdir -p "$TEMP_DIR"
    if [ -d "$WORKING_DIR" ] && [ "$(ls -A "$WORKING_DIR" 2>/dev/null)" ]; then
      cp -r "$WORKING_DIR"/* "$TEMP_DIR"/
    fi

    # Create and switch to new branch
    cd "$WORKING_DIR"
    git checkout -b "$BRANCH_NAME"

    # Bubblewrap sandbox with isolation
    ${pkgs.bubblewrap}/bin/bwrap \
      --ro-bind /nix/store /nix/store \
      --bind /run /run \
      --bind /etc /etc \
      --bind /dev /dev \
      --bind /proc /proc \
      --bind /sys /sys \
      --tmpfs /tmp \
      --bind "$TEMP_DIR" /work \
      --unshare-all \
      --uid 1000 \
      --gid 1000 \
      --dir /home/user \
      --chdir /work \
      --setenv HOME /home/user \
      --setenv PATH ${lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.git pkgs.neovim]} \
      ${lib.optionalString cfg.speedStorage "--bind /var/lib/opencode /var/lib/opencode"} \
      bash

    # Post-sync: copy changes back and commit
    if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR" 2>/dev/null)" ]; then
      cp -r "$TEMP_DIR"/* "$WORKING_DIR"/
    fi
    cd "$WORKING_DIR"
    git add .
    if git diff --cached --quiet; then
      echo "No changes to commit"
    else
      git commit -m "OpenCode session $BRANCH_NAME"
    fi

    # Cleanup
    rm -rf "$TEMP_DIR"
  '';
in
{
  options.services.opencode-sandbox = {
    enable = mkEnableOption "OpenCode sandbox service";

    workingDir = mkOption {
      type = types.str;
      default = "/home/pokej/NixOS-Configuration";
      description = "Working directory for the repository";
    };

    speedStorage = mkOption {
      type = types.bool;
      default = true;
      description = "Mount /var/lib/opencode if available";
    };

    memoryLimit = mkOption {
      type = types.str;
      default = "1G";
      description = "Memory limit for sandbox processes";
    };

    cpuLimit = mkOption {
      type = types.str;
      default = "50%";
      description = "CPU limit for sandbox processes";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.opencode-sandbox = {
      description = "OpenCode Sandbox Session";
      serviceConfig = {
        ExecStart = "${sessionScript}/bin/opencode-session";
        User = "pokej";
        MemoryLimit = cfg.memoryLimit;
        CPUQuota = cfg.cpuLimit;
        Type = "oneshot";
        RemainAfterExit = true;
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.opencode-sandbox-cleanup = {
      description = "Cleanup OpenCode Sandbox Sessions";
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c 'rm -rf /tmp/opencode-session-*'";
        Type = "oneshot";
      };
    };
  };
}