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
      ../../environments/i3wm_darthpjb.nix
      ../../environments/steam.nix
      ../../environments/code.nix
      ../../environments/neovim.nix
      ../../environments/communications.nix
      ../../environments/browsers.nix
      ../../environments/cad_and_graphics.nix
      ../../environments/3dPrinting.nix
      ../../environments/audio_visual_editing.nix
      ../../environments/general_fonts.nix
      ../../environments/video_call_streaming.nix
      ../../environments/cloud_and_backup.nix
      ../../environments/rtl-sdr.nix
      ../../modifier_imports/bluetooth.nix
      ../../modifier_imports/hosts.nix
      ../../modifier_imports/cuda.nix
    ];
services.xserver.videoDrivers = [ "nvidia" ];
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

  hardware = {
    sane.enable = true;
    graphics.enable = true;
    graphics.enable32Bit = true;
    nvidia = {
      nvidiaSettings = true;
      open = false;
      modesetting.enable = false;
      powerManagement.enable = true;
    };
  };
}

