{ pkgs, config, lib, self, ... }:
let
  hostname = "display-1";
in
{

  imports = [
    ../../modifier_imports/zram.nix
    ../../lib/enable-wg.nix
    ../../configuration.nix
    #../../environments/hyperland.nix
    ../../environments/i3wm.nix
    ../../environments/browsers.nix
  ];
  system.name = "${hostname}";
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  sdImage.compressImage = false;
  secrix.services.wireguard-wireg0.secrets."${hostname}".encrypted.file = "${self}/secrets/wiregaurd/wg_${hostname}";
  environment.vpn =
    {
      enable = true;
      postfix = 41;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
    };
  systemd.user.services.browser =
    {
      enable = true;
      description = "browser-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${lib.getExe pkgs.chromium}
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
  systemd.user.services.terminal =
    let
      config_file = pkgs.writeText "theme.toml" ''
        [colors.primary]
        background = '#000000'
        foreground = '#b6b6b6'

        # Normal colors
        [colors.normal]
        black   = '#000000'
        red     = '#990000'
        green   = '#00a600'
        yellow  = '#999900'
        blue    = '#0000b2'
        magenta = '#b200b2'
        cyan    = '#00a6b2'
        white   = '#bfbfbf'

        # Bright colors
        [colors.bright]
        black   = '#666666'
        red     = '#e50000'
        green   = '#00d900'
        yellow  = '#e5e500'
        blue    = '#0000ff'
        magenta = '#e500e5'
        cyan    = '#00e5e5'
        white   = '#e5e5e5'
      '';
    in
    {
      enable = true;
      description = "terminal-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${lib.getExe pkgs.alacritty} --config-file ${config_file} -e "${lib.getExe pkgs.bottom}"
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
  hardware = {
    enableRedistributableFirmware = true;
    raspberry-pi."4" =
      {
        apply-overlays-dtmerge.enable = true;
        fkms-3d.enable = true;
      };
    deviceTree = {
      enable = true;
    };
  };
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
  boot = {
    initrd.kernelModules = [ "vc4" "snd_bcm2835" ];
    #  supportedFilesystems.zfs = lib.mkForce false;
    #  kernelPackages = pkgs.linuxPackages_rpi4;
    kernelParams = [ "video=HDMI-A-1:1920x1080@60" "console=ttyS1,115200n8" "cma=128M" ];
    extraModprobeConfig = ''
      options snd_bcm2835 enable_headphones=1 enable_hdmi=1
    '';
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };


  swapDevices = [{ device = "/swapfile"; size = 1024; }];
  services.openssh.enable = true;
  networking = {
    hostName = "${hostname}";
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
}
