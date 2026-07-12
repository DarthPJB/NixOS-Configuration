# modules/ssh-multiplex.nix
# Fleet-wide SSH connection multiplexing.
#
# Configures SSH control master settings so that repeated SSH connections to
# the same host reuse a single TCP connection. This significantly reduces
# connection latency for fleet operations (deployments, monitoring, etc.).
#
# The socket directory is created via systemd-tmpfiles so that the control
# sockets persist across boots without requiring a per-user runtime dir.
#
# Usage in flake.nix commonModules:
#   imports = [ ... ./modules/ssh-multiplex.nix ];
#
# Or to enable on a specific machine:
#   sshMultiplex.enable = true;
{ config, lib, ... }:

let
  cfg = config.sshMultiplex;
in
{
  options.sshMultiplex = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable fleet-wide SSH connection multiplexing.
        When enabled, repeated SSH connections to the same host reuse
        a single persistent TCP connection via a control socket.
        The control socket persists for 15 minutes after the last
        connection closes.
      '';
    };

    controlPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/ssh-mux/%r@%h:%p";
      description = ''
        Path template for the SSH control socket.
        Substituted by ssh: %r (remote user), %h (host), %p (port).
      '';
    };

    controlPersist = lib.mkOption {
      type = lib.types.str;
      default = "15m";
      description = ''
        How long the control socket persists after the master
        connection closes. Examples: "15m", "1h", "yes" (forever).
      '';
    };

    socketDirMode = lib.mkOption {
      type = lib.types.str;
      default = "0755";
      description = "File mode for the SSH multiplexing socket directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh.extraConfig = ''
      # Fleet-wide SSH multiplexing (ssh-multiplex module)
      Host *
        ControlMaster auto
        ControlPath ${cfg.controlPath}
        ControlPersist ${cfg.controlPersist}
    '';

    systemd.tmpfiles.rules = [
      "d /run/ssh-mux ${cfg.socketDirMode} root root"
    ];
  };
}
