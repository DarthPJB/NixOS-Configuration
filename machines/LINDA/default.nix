# -------------------------- LINDACORE --------------------------
{ config, pkgs, self, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../lib/enable-wg.nix
      ../../lib/rclone-target.nix
    ];
  secrix.services.wireguard-wireg0.secrets.LINDA.encrypted.file = ../../secrets/wg_LINDA;
  environment = {
    vpn =
      {
        enable = true;
        postfix = 88;
        privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.LINDA.decrypted.path;
      };
    rclone-target = {
      enable = true;
      configFile = "${self}/secrets/rclone-config-file";
      targets = {
        obsidian-v3 = {
          filePath = " /bulk-storage/88-DB-v3/";
          remoteName = "minio:obsidian-v3";
          syncInterval = 60; # every minute
        };
      };
    };
  };
  environment.systemPackages = [
    self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.looking-glass-client
    self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.scream
    pkgs.virtiofsd
    pkgs.gwe
    pkgs.virt-manager
    #self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.nixd
  ];
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  services.printing.enable = true;#
  services.guix.enable = true;
  programs.adb.enable = true;
  users.users.John88.extraGroups = [ "adbusers" ];
  systemd.user.services =
    {
      obsidian =
        {
          description = "obsidian-autostart";
          wantedBy = [ "graphical-session.target" ];
          serviceConfig =
            {
              Restart = "always";
              ExecStart = ''
                ${pkgs.obsidian}/bin/obsidian
              '';
              PassEnvironment = "DISPLAY XAUTHORITY";
            };
        };
      dino =
        {
          description = "dino-autostart";
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
      discord =
        {
          description = "discord-autostart";
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

      scream-ivshmem = {
        enable = true;
        description = "Scream br0";
        serviceConfig = {
          ExecStart = "${pkgs.scream}/bin/scream  -u -i  br0 -p 4010";
        };
        wantedBy = [ "multi-user.target" ];
        requires = [ "pipewire.service" ];
      };
    };

  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 John88 qemu-libvirtd -"
    "d /rendercache 0755 John88 users"
  ];

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
        DEVS="0000:21:00.0 0000:21:00.1 0000:46:00.0"
        for DEV in $DEVS; do
            echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
        done
        modprobe -i vfio-pci
      '';
    };


  # Set your time zone.
  time.timeZone = "Etc/UTC";
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

  networking = {
    interfaces = {
      br0.useDHCP = true;
      enp69s0f0 = {
        useDHCP = true;
      };
      enp69s0f1 = {
        useDHCP = true;
      };
    };
    firewall.interfaces = {
      "br0".allowedTCPPorts = [ 2108 4010 1108 27000 27003 ];
      "br0".allowedTCPPortRanges = [{ from = 27020; to = 27021; }];
      "wireg0".allowedTCPPorts = [ 80 ];

      "br0".allowedUDPPorts = [ 2108 1108 4010 27000 27003 ];
      "br0".allowedUDPPortRanges = [{ from = 27020; to = 27021; }];
      "wireg0".allowedUDPPorts = [ 1108 ];

    };

    hostName = "LINDACORE";
    hostId = "b4120de4";
    bridges = {
      "br0" = {
        interfaces = [ "enp69s0f0" ];
      };
    };
    useDHCP = false;
    wireless =
      {
        enable = false; # Enables wireless support via wpa_supplicant.
        userControlled.enable = true;
        interfaces = [ "wlp72s0" ];
      };
  };
}

