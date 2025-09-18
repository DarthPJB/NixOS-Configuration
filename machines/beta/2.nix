{ pkgs, config, lib, self, ... }:
let
  hostname = "beta-two";
in
{

  imports = [
    ../../lib/enable-wg.nix
    #../../environments/i3wm.nix
    #../../environments/browsers.nix
  ];
  documentation.man.enable = false;
  system.name = "${hostname}";

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
  };
}
