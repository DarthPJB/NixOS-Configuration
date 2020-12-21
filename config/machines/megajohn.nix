{ config, pkgs, ... }:
{

  # Use the GRUB 2 boot loader.
  boot.loader = {
	grub = {
	    enable = true;
	    version = 2;
	    configurationLimit = 5;
	    efiSupport = true;
	    efiInstallAsRemovable = true;
	    device = "nodev"; # or "nodev" for efi only
	  };
        systemd-boot = {
	    enable = true;
	    };
	};

  # Networking 
  networking = {
    hostName = "megajohn"; # Define your hostname.
    interfaces = {
	enp0s31f6.useDHCP = true;
	wlp4s0.useDHCP = true;
    };
  };
  
  hardware = {
    opengl.enable = true;
    pulseaudio.enable = true;
  };

  powerManagement.enable = true;

  # Enable sound.
  sound.enable = true;

    services = {
        # Enable the OpenSSH daemon.
        openssh.enable = true;
        # Enable touchpad support (enabled default in most desktopManager).
        xserver = { 
            # TODO: update this with appropriate entries
            #displayManager.setupCommands = 
	    digimend.enable = true;
            videoDrivers = [ "nvida" ];
        };
        # Enable CUPS to print documents.
        printing.enable = true;
    };
}
