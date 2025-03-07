# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ self, config, pkgs, inputs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  environment.systemPackages = [
    inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.looking-glass-client
    inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.scream
    pkgs.virtiofsd
    pkgs.gwe
    pkgs.virt-manager
    self.un_pkgs.nixd
  ];
  services.avahi = {
  enable = true;
  nssmdns4 = true;
  openFirewall = true;
};
services.printing.enable = true;
  systemd.user.services.discord =
    {
      description = "mumble-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${pkgs.discord}/bin/discord
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
  systemd.user.services.dino =
    {
      description = "mumble-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${pkgs.dino}/bin/dino
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };

  systemd.mounts = [
    {
      where = "/rendercache";
      what = "/speed-storage/rendercache";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" ];
      wantedBy = [ "multi-user.target" ];
    }
    {
      where = "/bulk-storage/nas-archive/remote.worker/88/88-FS-V2/rendercache";
      what = "/speed-storage/rendercache";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" ];
      wantedBy = [ "multi-user.target" ];
    }
    {
      where = "/var/tmp";
      what = "/speed-storage/tmp";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" ];
      wantedBy = [ "multi-user.target" ];
    }
  ];
  fileSystems."/tmp" =
    {
      device = "speed-storage/tmp";
      fsType = "zfs";
    };
  fileSystems."/var/lib/libvirt" =
    {
      device = "speed-storage/var-lib-libvirt";
      fsType = "zfs";
      options = [ "nofail" ];
    };
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 John88 qemu-libvirtd -"
    "f /dev/shm/scream 0660 John88 qemu-libvirtd -"
    "d /rendercache 0755 John88 users"
  ];
  systemd.user.services.scream-ivshmem = {
    enable = true;
    description = "Scream br0";
    serviceConfig = {
      ExecStart = "${pkgs.scream}/bin/scream -i br0";
      Restart = "always";
      RuntimeMaxSec = "240";
    };
    wantedBy = [ "multi-user.target" ];
    requires = [ "pipewire.service" ];
  };
  boot =
    {
      tmp.useTmpfs = false;
      supportedFilesystems = [ "zfs" "ntfs" ];
      zfs.extraPools = [ "speed-storage" "bulk-storage" ];
      loader =
        {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
      initrd =
        {
          availableKernelModules = [ "vfio_pci" "vfio_iommu_type1" "vfio" "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "uas" "sd_mod" ];
          kernelModules = [ "vfio_pci" ];
        };

      #kernelPackages= pkgs.linuxPackages_5_18;
      kernelModules = [ "kvm-amd" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" ];
      kernelParams = [
        "amd_iommu=on"
      ];
      extraModulePackages = [ ];



      extraModprobeConfig = ''
        options vfio-pci ids=10de:2487,10de:228b,1d6b:0002,28de:2102,28de:2300,0424:2744,28de:2613,28de:2400
      '';
      initrd.preDeviceCommands = ''
        DEVS="0000:21:00:.0 0000:21:00.1 0000:46:00.0"
        for DEV in $DEVS; do
            echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
        done
        modprobe -i vfio-pci
      '';
    };


  # Set your time zone.
  time.timeZone = "Europe/London";
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware = {
    sane.enable = true;
    graphics.enable = true;
    cpu.amd.updateMicrocode = config.hardware.enableRedistributableFirmware;
    graphics.enable32Bit = true;
    nvidia = {
      nvidiaSettings = true;
      open = false;
      modesetting.enable = false;
      powerManagement.enable = true;
    };
  };
  networking =
    {
      firewall.allowedUDPPorts = [ 4010 51413 ];
      firewall.allowedTCPPorts = [ 51413 ];
      firewall.allowedUDPPortRanges = [{ from = 6881; to = 6999; }];
      firewall.allowedTCPPortRanges = [{ from = 6881; to = 6999; }];
      hostName = "LINDACORE";
      hostId = "b4120de4";
      bridges = {
        "br0" = {
          interfaces = [ "enp69s0f0" ];
        };
      };
      useDHCP = false;
      interfaces =
        {
          br0.useDHCP = true;
          enp69s0f0.useDHCP = false;
          enp69s0f1 = {
            useDHCP = false;
            ipv4.addresses = [{
              address = "192.168.2.10";
              prefixLength = 24;
            }];
          };
        };
      wireless =
        {
          enable = false; # Enables wireless support via wpa_supplicant.
          userControlled.enable = true;
          interfaces = [ "wlp72s0" ];
        };
    };
  system.stateVersion = "21.11"; # Did you read the comment?

}

