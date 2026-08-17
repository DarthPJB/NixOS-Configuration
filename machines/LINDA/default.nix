# -------------------------- LINDACORE --------------------------
{ config
, pkgs
, self
, lib
, hostname
, ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../services/ollama.nix
    ../../services/gitlab-credentials.nix
    ../../modules/enable-wg-topology.nix
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
    ../../locale/input-methods.nix
    ../../environments/rtl-sdr.nix
    ../../modifier_imports/bluetooth.nix
    ../../environments/denton-glasses.nix
    ../../modifier_imports/memtest.nix
    ../../modifier_imports/hosts.nix
    ../../modifier_imports/zfs.nix
    ../../modifier_imports/virtualisation-libvirtd.nix
    ../../modifier_imports/virtualisation-vmware.nix
    ../../environments/sshd.nix
    ../../modifier_imports/cuda.nix
    ../../modifier_imports/remote-builder.nix
  ];
  enableWgTopology.enable = true;
  programs.ssh.extraConfig = ''
    Host hyperhyper
      ControlMaster auto
      ControlPath /run/ssh-mux/%r@%h:%p
      ControlPersist 600
  '';

  networking.wireguard = {
    enable = true;
    interfaces = {
      wiregPS0 = {
        # ensure routes exist to other clients.
        postSetup = ''
          ${lib.getExe' pkgs.iproute2 "ip"} route add 10.75.69.0/24 dev wiregPS0
        '';
        postShutdown = ''
          ${lib.getExe' pkgs.iproute2 "ip"} route del 10.75.69.0/24 dev wiregPS0
        '';
        ips = [ "10.75.69.88/32" ];
        listenPort = 2107;
        privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
        peers = [
          {
            publicKey = builtins.readFile "${self}/secrets/public_keys/wireguard/wg_acropolis_pub";
            allowedIPs = [
              "10.75.69.1/32"
              "10.75.69.0/24"
            ];
            endpoint = "143.223.151.15:2208";
            dynamicEndpointRefreshSeconds = 300;
            persistentKeepalive = 60;
          }
        ];
      };
    };
  };
  nix.gc.automatic = lib.mkForce false; # Never collect this nix-store and it's cache.
  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true;
  };
  virtualisation.docker.enable = true;
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
  #programs.adb.enable = true;
  users.users.John88.extraGroups = [ "adbusers" ];
  systemd.user.services = {
    obsidian = {
      description = "obsidian-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Restart = "always";
        ExecStart = ''
          ${lib.getExe pkgs.obsidian}
        '';
        PassEnvironment = "DISPLAY XAUTHORITY";
      };
    };
    dino = {
      description = "dino-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Restart = "always";
        ExecStart = ''
          ${lib.getExe pkgs.dino}
        '';
        PassEnvironment = "DISPLAY XAUTHORITY";
      };
    };
    discord = {
      description = "discord-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Restart = "always";
        ExecStart = ''
          ${lib.getExe pkgs.discord}
        '';
        PassEnvironment = "DISPLAY XAUTHORITY";
      };
    };
    scream-ivshmem = {
      enable = true;
      description = "Scream br0";
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.scream} -u -i br0 -p 4010";
      };
      wantedBy = [ "multi-user.target" ];
      requires = [ "pipewire.service" ];
    };
  };
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 John88 qemu-libvirtd -"
    "d /rendercache 0755 John88 users"
    "d /run/ssh-mux 0755 John88 users"
  ];
  boot = {
    tmp.useTmpfs = false;
    supportedFilesystems = [
      "zfs"
      "ntfs"
    ];
    zfs.extraPools = [
      "speed-storage"
      "bulk-storage"
    ];
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 1;
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "uas"
        "sd_mod"
        "nvidia-drm"
      ];
      kernelModules = [ ];
    };
    #kernelPackages= pkgs.linuxPackages_5_18;
    kernelModules = [
      "kvm-amd"
    ];
    kernelParams = [
      "video=HDMI-A-1:1920x1080@60"
      "video=HDMI-A-2:3840x2160@60"
      "video=DP-2:1920x1080@60"
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "acpi_enforce_resources=lax"
      "amd_iommu=on"
      "amd_pstate=active"
    ];
    extraModulePackages = [ ];
  };

  # Set your time zone.
  time.timeZone = "Etc/UTC";
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.displayManager.setupCommands = ''
    ${lib.getExe pkgs.xrandr} \
      --output HDMI-0 --mode 1920x1080 --pos 0x0 --rotate right \
      --output HDMI-1 --primary --mode 3840x2160 --pos 1080x0 --rotate normal \
      --output DP-3 --mode 1920x1080 --pos 4920x0 --rotate left
  '';
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
            actions = {
              quirks = [ "block-source-volume" ];
            };
          }
        ];
      };
      "50-vivaldi-block-source-volume" = {
        "pulse.rules" = [
          {
            matches = [
              { application.process.binary = "*[V]ivaldi*"; }
            ];
            actions = {
              quirks = [ "block-source-volume" ];
            };
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
      powerManagement.enable = false;
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
      "enp69s0f0".allowedTCPPorts = [
        2108
        4010
        1108
        5201
        27015
        4549
        24070
      ];
      "enp69s0f0".allowedTCPPortRanges = [
        {
          from = 17780;
          to = 17785;
        }
        {
          from = 47984;
          to = 48010;
        }
      ];
      "wireg0".allowedTCPPorts = [
        80
        1108
        5201
        42420
      ];

      "enp69s0f0".allowedUDPPorts = [
        2108
        2107
        1108
        4010
        27015
        4175
        4179
        4171
      ];
      "enp69s0f0".allowedUDPPortRanges = [
        {
          from = 17780;
          to = 17785;
        }
        {
          from = 27031;
          to = 27036;
        }
        {
          from = 47984;
          to = 48010;
        }
      ];

    };
    #    bonds."bond0" = {
    #      interfaces = [ "enp69s0f1" "enp69s0f0" ];
    #      driverOptions = {
    #        mode = "active-backup";
    #        miimon = "100";
    #      };
    #    };

    #hostName = "LINDACORE";
    hostId = "b4120de4";
    #    bridges = {
    #      "br0" = {
    #        interfaces = [ "enp69s0f0" ];
    #      };
    #    };
    useDHCP = false;
    wireless = {
      enable = false; # Enables wireless support via wpa_supplicant.
      userControlled = true;
      interfaces = [ "wlp72s0" ];
    };
  };

  # secrix secret declarations for MCP tokens
  secrix.system.secretsDir = {
    permissions = "0555";
    user = "root";
    group = "users";
  };
  secrix.system.secrets.github-PAT-token = {
    encrypted.file = "${self}/secrets/github-PAT-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.gitlab-PAT-token = {
    encrypted.file = "${self}/secrets/gitlab-PAT-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.openrouter-master-token = {
    encrypted.file = "${self}/secrets/openrouter-master-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.LINDA-openCODE-token = {
    encrypted.file = "${self}/secrets/LINDA-openCODE-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.LINDA-xAI-token = {
    encrypted.file = "${self}/secrets/LINDA-xAI-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.mimo-token-plan-ai-key = {
    encrypted.file = "${self}/secrets/mimo-token-plan-ai-key";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };

  # OpenCode fleet configuration — full fleet with MCP servers
  services.opencode-fleet = {
    enable = true;
    user = "John88";
    home = "/home/John88";
    mcp.git = {
      enable = true;
      extraArgs = [ "--repository" "/home/pokej/NixOS-Configuration" ];
    };
    mcp.filesystem = {
      enable = true;
      paths = [ "/home/pokej" "/speed-storage" "/nix/store" "/home/pokej/NixOS-Configuration" ];
    };
    mcp.time.enable = true;
    mcp.sqlite.enable = true;
    mcp.playwright.enable = true;
    mcp.github = {
      enable = true;
      tokenFile = config.secrix.system.secrets.github-PAT-token.decrypted.path;
    };
    mcp.gitlab = {
      enable = true;
      tokenFile = config.secrix.system.secrets.gitlab-PAT-token.decrypted.path;
    };
    mcp.prometheus = {
      enable = true;
      prometheusUrl = "http://10.88.127.3:8080";
    };
    mcp.nix-mcp.enable = true;
    providers.openrouter = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.openrouter-master-token.decrypted.path;
    };
    providers.opencode-go = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.LINDA-openCODE-token.decrypted.path;
    };
    providers.xiaomi-token-plan-sgp = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.mimo-token-plan-ai-key.decrypted.path;
    };
    providers.xai = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.LINDA-xAI-token.decrypted.path;
    };
  };

}
