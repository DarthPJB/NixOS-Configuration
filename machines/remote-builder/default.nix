{ config, pkgs, lib, self, ... }:
{
  imports = [
    ../../lib/enable-wg.nix
  ];
  secrix.services.wireguard-wireg0.secrets.remote-builder.encrypted.file = ../../secrets/wiregaurd/wg_remote-builder;
  environment.vpn =
    {
      enable = true;
      postfix = 51;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.remote-builder.decrypted.path;
    };
}
