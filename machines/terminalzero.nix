# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{

  # Use the GRUB 2 boot loader.
  # Use the systemd-boot EFI boot loader.
  boot.loader =
    {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking =
    {
      useDHCP = false;
      hostName = "Terminal-zero"; # Define your hostname.
      interfaces =
        {
          enp0s25.useDHCP = true;
          wlp3s0.useDHCP = true;
          wwp0s29u1u4i6.useDHCP = true;
        };
      wireless =
        {
          enable = true; # Enables wireless support via wpa_supplicant.
          userControlled.enable = true;
          interfaces = [ "wwp0s29u1u4i6" "wlp3s0" ];
        };
    };

  # Enable CUPS to print documents.
  # Enable touchpad support (enabled default in most desktopManager).
  services =
    {
      xserver.libinput.enable = true;
      printing.enable = true;
    };

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot =
    {
      initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" "uas" "sd_mod" "rtsx_pci_sdmmc" ];
      kernelModules = [ "kvm-intel" ];
    };

  fileSystems = {
    "/" =
      {
        device = "/dev/disk/by-label/TerminalZero";
        fsType = "ext4";
      };

    "/boot" =
      {
        device = "/dev/disk/by-label/TZBOOT";
        fsType = "vfat";
      };
  };

  swapDevices = [{ device = "/dev/disk/by-label/swap"; }];

  # This value determines the NixOS release from which the default
  # settings for stateful data
  system.stateVersion = "21.05"; # Did you read the comment?
}