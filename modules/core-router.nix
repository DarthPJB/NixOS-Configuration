# modules/core-router.nix
# Consumes real-topology data and generates actual NixOS networking configuration
{ config, lib, pkgs, self, ... }:
{
  # This module will eventually replace much of the inline networking logic
  # in cortex-alpha and other routers.
  # For now, it just adds the UDP GRO service which was previously inline.

  # TODO: lift to common (modifier_imports/tailscale-udp-gro.nix) if needed later
  # This fix only applies to cortex-alpha for now
  environment.systemPackages = [ pkgs.ethtool ];
  systemd.services.tailscale-udp-gro = {
    description = "Enable UDP GRO forwarding for tailscale performance on enp2s0";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool -K enp2s0 rx-udp-gro-forwarding on";
      RemainAfterExit = true;
    };
  };
}
