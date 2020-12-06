{ config, pkgs, ... }:
{
  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.configurationLimit = 5;
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  # Networking 
  networking.hostName = "terminalzero"; # Define your hostname.
  networking.interfaces.enp0s25.useDHCP = true;
  networking.interfaces.wlp3s0.useDHCP = true;
  networking.interfaces.wwp0s29u1u4i6.useDHCP = true;
  
  # Enable CUPS to print documents.
  services.printing.enable = true;
  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # TODO: update this with appropriate entries
  # services.xserver.displayManager.setupCommands = 

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}