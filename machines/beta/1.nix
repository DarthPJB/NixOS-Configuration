{ pkgs, config, lib, self, ... }:
let
  hostname = "beta-one";
in
{

  imports = [
    ../../lib/enable-wg.nix
    #../../environments/i3wm.nix
    #../../environments/browsers.nix
  ];
  system.name = "${hostname}";
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  sdImage.compressImage = false;
  #secrix.services.wireguard-wireg0.secrets."${hostname}".encrypted.file = "${self}/secrets/wg_${hostname}";
  #environment.vpn =
  #  {
  #    enable = true;
  #    postfix = 41;
  #   privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
  # };

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
