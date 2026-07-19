{ config
, pkgs
, lib
, self
, hostname
, ...
}:
{
  imports = [
    ./hardware-configuration.nix
    # ../../configuration.nix — already in commonModules (flake.nix), do not duplicate
    ../../users/darthpjb.nix
    ../../modifier_imports/flakes.nix
    ../../environments/sshd.nix
    ../../environments/tools.nix
    ../../services/dynamic_domain_gandi.nix
    ../../services/github_runners.nix
    ../../services/mkRunners.nix
    ../../services/gitlab-credentials.nix
    ../../modifier_imports/remote-builder.nix
    ../../users/build.nix
    ../../modules/enable-wg-topology.nix
  ];
  # Virtual disk devices — smartctl/smartd not applicable
  services.smartd.enable = lib.mkForce false;
  services.prometheus.exporters.smartctl.enable = lib.mkForce false;

  enableWgTopology.enable = true;

  # Build-runner hub: never build locally, distribute all builds to
  # hyperhyper (x86_64-linux) and arm-builder (aarch64-linux).
  nix.settings.max-jobs = 0;

  # Route to hyperhyper (100.107.101.14) via cortex-alpha WireGuard gateway
  # hyperhyper is on an external Tailscale VPN — cortex-alpha is the only
  # WireGuard hub with a Tailscale connection, so all traffic for hyperhyper
  # must go through it.
  #
  # Two things needed:
  # 1. WireGuard allowedIPs must include the Tailscale IP so the tunnel accepts it
  # 2. A route must direct traffic for that IP through the tunnel
  networking.wireguard.interfaces.wireg0.peers = lib.mkForce [
    {
      # cortex-alpha hub — extend allowedIPs to include hyperhyper Tailscale IP
      publicKey = builtins.readFile "${self}/secrets/public_keys/wireguard/wg_cortex-alpha_pub";
      allowedIPs = [ "10.88.127.0/24" "100.107.101.14/32" ];
      endpoint = "cortex-alpha.johnbargman.net:2108";
      persistentKeepalive = 25;
    }
  ];

  # Route for hyperhyper through WireGuard tunnel (dhcpcd-compatible)
  networking.localCommands = ''
    ${pkgs.iproute2}/bin/ip route replace 100.107.101.14/32 via 10.88.127.1 dev wireg0 2>/dev/null || true
  '';
}
