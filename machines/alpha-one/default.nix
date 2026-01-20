# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, self, ... }:
let
  hostname = "alpha-one";
in
{
  networking.hostName = "${hostname}";
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../lib/enable-wg.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  secrix.services.wireguard-wireg0.secrets."${hostname}".encrypted.file = "${self}/secrets/wiregaurd/wg_${hostname}";
  environment.vpn =
    {
      enable = true;
      postfix = 108;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
    };

}

