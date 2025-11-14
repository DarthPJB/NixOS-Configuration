## --------------- LOCAL NAS aka data-storage ---------------


{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../lib/enable-wg.nix
      ../../modifier_imports/zram.nix
      ../../modifier_imports/zfs.nix
      ../../server_services/minio-insecure.nix
      ../../environments/neovim.nix
      ../../environments/emacs.nix
      ../../environments/sshd.nix
    ];

  secrix.services.wireguard-wireg0.secrets.local_nas.encrypted.file = ../../secrets/wiregaurd/wg_local-nas;
  environment.vpn =
    {
      enable = true;
      postfix = 3;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.local_nas.decrypted.path;
    };

  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = "1048576"; # 128 times the default 8192
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "archive" "bulk-storage" ];
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot = {
      flags = "-k -p --utc";
      enable = true;
    };
  };
  systemd.mounts = [
    {
      #depends = [ "/archive" "/bulk-storage" ];
      what = "/archive/general";
      where = "/bulk-storage/NAS-ARCHIVE/ARCHIVE";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" "zfs-mount.service" ];
      wantedBy = [ "multi-user.target" ];
    }
    {
      #depends = [ "/archive" "/bulk-storage"];
      what = "/archive/astral";
      where = "/bulk-storage/NAS-ARCHIVE/remote.worker/Astralship Master Archive/ARCHIVE";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" "zfs-mount.service" ];
      wantedBy = [ "multi-user.target" ];
    }
    {
      #depends = [ "/archive" "/bulk-storage"];
      what = "/archive/personal";
      where = "/bulk-storage/NAS-ARCHIVE/remote.worker/88/88-FS-V2/ARCHIVE";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" "zfs-mount.service" ];
      wantedBy = [ "multi-user.target" ];
    }
  ];

  networking.hostId = "d5710c9a";
  networking.hostName = "DataStorage"; # Define your hostname.
  time.timeZone = "Etc/UTC";
  system.stateVersion = "22.11"; # Did you read the comment?

  environment.systemPackages = [ pkgs.networkmanagerapplet ];

}

