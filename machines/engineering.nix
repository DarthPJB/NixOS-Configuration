{ config, pkgs, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ../enviroments/i3wm_darthpjb.nix
      ../enviroments/general_fonts.nix
      ../enviroments/cad_and_graphics.nix
      ../enviroments/code.nix
      ../enviroments/sshd.nix
      ../enviroments/bluetooth.nix
      ../enviroments/rtl-sdr.nix
      ../users/pirate.nix
      ../locale/en_gb.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    initrd.kernelModules = [ "amdgpu" ];
  };

  networking = {
    useDHCP = false;
    hostName = "Engineering";
    interfaces = {
      enp1s0.useDHCP = true;
      wlp2s0.useDHCP = true;
    };
  };

  sound.enable = true;
  hardware.pulseaudio.enable = true;
  # Enable the OpenSSH daemon.
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 1108 ];
  networking.firewall.allowedUDPPorts = [ ];

  services = {
    # Enable the OpenSSH daemon.
    openssh = {
      enable = true;
      ports = [ 1108 ];
      passwordAuthentication = false;
    };
    # Enable touchpad support (enabled default in most desktopManager).
    xserver = {
      # TODO: update this with appropriate entries
      #displayManager.setupCommands =
      libinput.enable = true;
      digimend.enable = true;
      videoDrivers = [ "amdgpu" ];
    };
    # Enable CUPS to print documents.
    printing.enable = true;
  };

  system.stateVersion = "20.09"; # Did you read the comment?
}
