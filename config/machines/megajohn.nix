{ config, pkgs, ... }:

  let
  baseconfig = { allowUnfree = true; };
  unstableTarball =
    fetchTarball
      https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz;
  unstable = import unstableTarball
  {
    config = baseconfig;
  };
  in
{
  imports =
  [ # Include the results of the hardware scan.
#    ../modifier_imports/unstable_nixpkgs.nix todo: figure out if this is possible
    ../modifier_imports/flakes.nix
    ../enviroments/audio_visual_editing.nix
    ../enviroments/i3wm_darthpjb.nix
    ../enviroments/general_fonts.nix
    ../enviroments/cad_and_graphics.nix
    ../enviroments/cadquery.nix
    ../enviroments/code.nix
    ../enviroments/bluetooth.nix
    ../enviroments/sshd.nix
    ../enviroments/rtl-sdr.nix
    ../users/darthpjb.nix
    ../locale/en_gb.nix
#    <unstable/nixos/modules/services/hardware/spacenavd.nix>
  ];
  # Use the GRUB 2 boot loader.
  boot = {
    supportedFilesystems = [ "ntfs" ];
    kernelPackages = unstable.linuxPackages_latest;
    blacklistedKernelModules = ["nouveau"];
    loader = {
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
#      kernelModules = [
#      "vfio_virqfd"
#      "vfio_pci"
#      "vfio_iommu_type1"
#      "vfio"
#      "kvm-intel" ];
#      blacklistedKernelModules = ["nouveau" "nvidia"];
#      kernelParams = ["intel_iommu=on"];
#      extraModprobeConfig = "options vfio-pci ids=10de:1401,8086:1912";
#        postBootCommands = ''
#        DEVS="0000:0f:00.0 0000:0f:00.1"

#        for DEV in $DEVS; do
#          echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
#        done
#        modprobe -i vfio-pci
#     '';
	};

  nixpkgs.config = {
    allowUnfree = true;
  };
  # Networking
  networking = {
    hostName = "megajohn"; # Define your hostname.
    interfaces = {
	     enp0s31f6.useDHCP = true;
	      wlp4s0.useDHCP = true;
    };
  };

  environment.systemPackages = with pkgs; [
    virtmanager
  ];

## VIRTUALISATION BULLMANURE
#programs.dconf.enable = true;

#  virtualisation.libvirtd = {
#    enable = true;
#    qemuOvmf = true;
#    qemuRunAsRoot = false;
#    onBoot = "ignore";
#    onShutdown = "shutdown";
#  };

  #hardware settings
  nixpkgs.config.packageOverrides = pkgs: {
    spacenavd = unstable.spacenavd;
  };

  hardware = {
    opengl.enable = true;
    pulseaudio.enable = true;
    opengl.driSupport32Bit = true;
    pulseaudio.support32Bit = true;
#    spacenavd.enable = true;
  };

  services.ipfs = {
    enable = true;
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
            videoDrivers = [ "nvidia" ];
        };
        # Enable CUPS to print documents.
        printing.enable = true;
    };
}
