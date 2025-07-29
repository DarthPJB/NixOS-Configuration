# ----------- Remote Worker -----------------

{ config, pkgs, ... }:

{
  imports =
    [
      ../../lib/enable-wg.nix
    ];
  secrix.services.wireguard-wireg0.secrets.remote-worker.encrypted.file = ../../secrets/wg_remote-worker;
  environment.vpn =
    {
      enable = true;
      postfix = 50;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.remote-worker.decrypted.path;
    };

  networking.hostId = "e3fabb5b";
  networking.hostName = "remote-worker";

}

