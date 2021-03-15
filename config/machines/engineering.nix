{ config, pkgs, ... }:
{
  imports =
  [ # Include the results of the hardware scan.
    ../enviroments/i3wm_darthpjb.nix
    ../enviroments/general_fonts.nix
    ../enviroments/cad_and_graphics.nix
    ../enviroments/code.nix
    ../enviroments/sshd.nix
    ../enviroments/bluetooth.nix
    ../enviroments/rtl-sdr.nix
    ../users/darthpjb.nix
    ../locale/en_gb.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot={
    loader={
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    initrd.kernelModules  = ["amdgpu"];
  };

  networking={
    useDHCP = false;
    hostName = "Engineering";
    interfaces={
      enp1s0.useDHCP = true;
      wlp2s0.useDHCP = true;
    };
  };

  services.xserver.videoDrivers = ["amdgpu"];
  # Enable CUPS to print documents.
  services.printing.enable = true;
  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.ports = [ 1108 ];
  services.openssh.passwordAuthentication = false;
 # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 1108 ];
  networking.firewall.allowedUDPPorts = [];


  system.stateVersion = "20.09"; # Did you read the comment?
}
