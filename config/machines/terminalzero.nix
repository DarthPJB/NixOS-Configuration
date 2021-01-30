{ config, pkgs, ... }:
{
  imports =
  [ # Include the results of the hardware scan.
    ../enviroments/i3wm_darthpjb.nix
    ../enviroments/general_fonts.nix
    ../enviroments/cad_and_graphics.nix
    ../enviroments/code.nix
    ../enviroments/rtl-sdr.nix
    ../users/darthpjb.nix
    ../locale/en_gb.nix
  ];
  # Use the GRUB 2 boot loader.
  boot.loader.grub = {
    enable = true;
    version = 2;
    configurationLimit = 5;
    device = "/dev/sda"; # or "nodev" for efi only
  };

  # Networking
  networking = {
    hostName = "terminalzero"; # Define your hostname.
    interfaces = {
        enp0s25.useDHCP = true;
        wlp3s0.useDHCP = true;
        wwp0s29u1u4i6.useDHCP = true;
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
            libinput.enable = true;
	    digimend.enable = true;
        };
        # Enable CUPS to print documents.
        printing.enable = true;
    };
}
