# -------------------------- LINDACORE --------------------------
{ config, pkgs, self, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  environment.systemPackages = [
    self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.looking-glass-client
    self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.scream
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
  programs.adb.enable = true;
  users.users.John88.extraGroups = [ "adbusers" ];
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
  fileSystems."/var/lib/tailscale" =
    {
      device = "bulk-storage/var-lib-tailscale";
      fsType = "zfs";
      options = [ "nofail" ];
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
  secrix.services.wireguard-wireg0.secrets.cortex-alpha.encrypted.file = ../../secrets/wg_LINDA;
  networking = {
    wireguard = { 
      enable = true;
      interfaces = {
        wireg0 = 
        {
          # Determines the IP address and subnet of the server's end of the tunnel interface.
          ips = [ "10.88.127.88/32" ];

          # The port that WireGuard listens to. Must be accessible by the client.
          listenPort = 2108;

          # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
          # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
         /* postSetup = ''
            ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.88.127.0/24 -o enp2s0 -j MASQUERADE
          '';

          # This undoes the above command
          postShutdown = ''
            ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.88.127.0/24 -o enp2s0 -j MASQUERADE
          '';*/

          # Path to the private key file.
          privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;

          peers = [{ 
              # Public key of the peer (not a file path).
              publicKey = "./secrets/wg_cortex-alpha_pub";
              # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
              allowedIPs = [ "10.88.127.0/24" ];
              endpoint = "192.168.0.193";
          }];
        };
      };
    };
    interfaces = {
      br0.useDHCP = true;
      enp69s0f0 = {
        useDHCP = true;
      };
      enp69s0f1 = {
        useDHCP = true;
      };
    };
    firewall.allowedUDPPorts = [ 4010 51413 2108 ];
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
    wireless =
    {
      enable = false; # Enables wireless support via wpa_supplicant.
      userControlled.enable = true;
      interfaces = [ "wlp72s0" ];
    };
  };
}

