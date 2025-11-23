{ config, pkgs, lib, self, ... }:
{
  imports = [
    ../../configuration.nix
    ../../users/darthpjb.nix
    ../../modifier_imports/flakes.nix
    ../../environments/sshd.nix
    ../../environments/tools.nix
    ../../services/dynamic_domain_gandi.nix
    ../../services/github_runners.nix
    ../../users/build.nix
    ../../lib/enable-wg.nix
  ];
  networking.hostName = "remote-builder"; # remote-builder"; #TODO: decide between DNS and WG-IP
  secrix.services.wireguard-wireg0.secrets.remote-builder.encrypted.file = ../../secrets/wiregaurd/wg_remote-builder;
  environment.vpn =
    {
      enable = true;
      postfix = 51;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.remote-builder.decrypted.path;
    };
}
