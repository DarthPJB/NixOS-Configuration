# obs-box.nix — OBS Studio streaming box with auto-start and VNC
# Machine was retired. Stored as reference snippet.
#
# Key features:
# - OBS Studio auto-start on graphical session
# - x11vnc for remote access
# - ZFS storage pool
# - Syncthing with web GUI on port 8080
# - i3wm with auto-login (user: commander)
# - NVIDIA legacy driver (470)
# - Custom SSH port (1108)
# - OBS plugins: multi-rtmp, move-transition
#
# To reactivate: add obs-box to nixosConfigurations in flake.nix and restore machines/obs-box/

{ config
, pkgs
, lib
, hostname
, ...
}:
{

  # Auto-start OBS Studio on graphical session
  systemd.user.services.obs-auto = {
    description = "obs-studio-autostart";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "always";
      ExecStart = ''
        ${pkgs.obs-studio}/bin/obs
      '';
      PassEnvironment = "DISPLAY XAUTHORITY";
    };
  };

  # x11vnc for remote access
  systemd.user.services.x11vnc = {
    description = "run X11 vnc server";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "always";
      ExecStart = ''
        ${pkgs.x11vnc}/bin/x11vnc -display $DISPLAY 
      '';
      PassEnvironment = "DISPLAY XAUTHORITY";
    };
  };

  imports = [
    ./hardware-configuration.nix
  ];

  security = {
    sudo = {
      wheelNeedsPassword = false;
      extraConfig = ''
        %psudo ALL=(ALL) PASSWD: ALL
      '';
    };
  };

  # Disable screen blanking
  environment.extraInit = ''
    xset s off -dpms
  '';

  boot.loader.systemd-boot.enable = true;
  boot.zfs.extraPools = [ "storage" ];
  boot.loader.efi.canTouchEfiVariables = true;

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    guiAddress = "0.0.0.0:8080";
  };

  networking.hostId = "1d2797ef";
  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  users.users.commander = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGcZrafX+y1V7Q1lSZUSSR6R0ouIPuYL1KCAZw6kOsqe l33@nixos"
    ];
  };

  time.timeZone = "Etc/UTC";

  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "uk";
  };

  services.openssh.ports = [
    1108
    22
  ];

  networking.firewall.allowedTCPPorts = [
    1108
    8080
    22
    5900
  ];

  system.stateVersion = "22.11";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware = {
    sane.enable = true;
    opengl.enable = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    opengl.driSupport32Bit = true;
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
      modesetting.enable = false;
      powerManagement.enable = true;
    };
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  environment.systemPackages = [
    (pkgs.wrapOBS {
      plugins = with pkgs.obs-studio-plugins; [
        obs-multi-rtmp
        obs-move-transition
      ];
    })
  ];

  services = {
    xserver = {
      libinput.enable = true;
      videoDrivers = [ "nvidia" ];
      layout = "gb";
      displayManager = {
        defaultSession = "none+i3";
        autoLogin = {
          enable = true;
          user = "commander";
        };
      };
      windowManager.i3.enable = true;
    };
  };
}
