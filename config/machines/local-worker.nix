# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./libvirt-qemu/hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ### ------ VIRT BABY, YEAH!
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  system.stateVersion = "22.11"; # Did you read the comment?

}

