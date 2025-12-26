# -------------------------- LINDACORE --------------------------
{ config, pkgs, self, lib, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../lib/enable-wg.nix
      ../../lib/rclone-target.nix
      ../../environments/i3wm_darthpjb.nix
      ../../environments/steam.nix
      ../../environments/code.nix
      ../../environments/neovim.nix
      ../../environments/communications.nix
      ../../environments/emacs.nix
      ../../environments/browsers.nix
      ../../environments/mudd.nix
      ../../environments/cad_and_graphics.nix
      ../../environments/3dPrinting.nix
      ../../environments/audio_visual_editing.nix
      ../../environments/general_fonts.nix
      ../../environments/video_call_streaming.nix
      ../../environments/cloud_and_backup.nix
      ../../locale/tailscale.nix
      ../../environments/rtl-sdr.nix
      ../../modifier_imports/bluetooth.nix
      ../../modifier_imports/memtest.nix
      ../../modifier_imports/hosts.nix
      ../../modifier_imports/zfs.nix
      ../../modifier_imports/virtualisation-libvirtd.nix
      ../../environments/sshd.nix
      ../../modifier_imports/cuda.nix
      ../../modifier_imports/remote-builder.nix
    ];
  secrix.services.wireguard-wireg0.secrets.LINDA.encrypted.file = ../../secrets/wiregaurd/wg_LINDA;
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
  nix.gc.automatic = lib.mkForce false; # Never collect this nix-store and it's cache.
  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
  };
  #programs.zoom-us.enable = true;
  environment.systemPackages = [
    self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.looking-glass-client
    self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.scream
    pkgs.virtiofsd
    pkgs.gwe
    pkgs.virt-manager
    #self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.nixd
  ];
  nix = {
    settings = {
      download-buffer-size = 524288000;
      max-jobs = 30;
      cores = 0;
    };
    nrBuildUsers = 30;
  };
  services.printing.enable = true;
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
      kernelModules = [ "kvm-amd" "vfio_pci" "vfio_iommu_type1" "vfio" ];
      kernelParams = [
        "video=HDMI-0:1920x1080@60"
        "video=DP-1:1920x1080@60"
        "video=HDMI-1:3840x2160@60"
        "video=HDMI-2-0:400x1280@30"
        "acpi_enforce_resources=lax"
        "amd_iommu=on"
        "amd_pstate=active"
      ];
      extraModulePackages = [ ];



      /*extraModprobeConfig = ''
        options vfio-pci ids=1b21:2142,10de:1c81,10de:0fb9
      '';*/
      # ,
      # 0000:21:00.0 0000:21:00.1
      # echo ""
      /*
      initrd.preDeviceCommands = ''
        DEVS="0000:46:00.0 0000:4d:00.0 0000:4d:00.1"
        for DEV in $DEVS; do
            echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
        done
        modprobe -i vfio-pci
      ''; */
    };


  # Set your time zone.
  time.timeZone = "Etc/UTC";
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  services.pipewire = {
    extraConfig.pipewire-pulse = {
      "50-discord-block-source-volume" = {
        "pulse.rules" = [
          {
            matches = [
              { application.process.binary = "Discord"; }
              { application.process.binary = ".Discord-wrapped"; }
              { application.process.binary = "discord"; }
              { application.process.binary = "*[Dd]iscord*"; }
            ];
            actions = { quirks = [ "block-source-volume" ]; };
          }
        ];
      };
      "50-vivaldi-block-source-volume" = {
        "pulse.rules" = [
          {
            matches = [
              { application.process.binary = "*[V]ivaldi*"; }
            ];
            actions = { quirks = [ "block-source-volume" ]; };
          }
        ];
      };
    };
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
      modesetting.enable = true;
      powerManagement.enable = true;
    };
  };

  networking = {
    interfaces = {
#      "bond0".useDHCP = true;
      enp69s0f0 = {
        useDHCP = true;
      };
      enp69s0f1 = {
        useDHCP = true;
      };
    };
    firewall.interfaces = {
      "enp69s0f0".allowedTCPPorts = [ 2108 4010 1108 5201 27015 4549 24070 ];
      "enp69s0f0".allowedTCPPortRanges = [{ from = 17780; to = 17785; }];
      "wireg0".allowedTCPPorts = [ 80 1108 5201 ];

      "enp69s0f0".allowedUDPPorts = [ 2108 1108 4010 27015 4175 4179 4171 ];
      "enp69s0f0".allowedUDPPortRanges = [{ from = 17780; to = 17785; }{ from = 27031; to = 27036;}];

    };
#    bonds."bond0" = {
#      interfaces = [ "enp69s0f1" "enp69s0f0" ];
#      driverOptions = {
#        mode = "active-backup";
#        miimon = "100";
#      };
#    };

    hostName = "LINDACORE";
    hostId = "b4120de4";
#    bridges = {
#      "br0" = {
#        interfaces = [ "enp69s0f0" ];
#      };
#    };
    useDHCP = false;
    wireless =
      {
        enable = false; # Enables wireless support via wpa_supplicant.
        userControlled.enable = true;
        interfaces = [ "wlp72s0" ];
      };
  };
}

