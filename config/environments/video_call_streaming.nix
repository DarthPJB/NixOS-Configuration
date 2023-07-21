{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    obs-studio
    #	obs-v4l2sink
  ];
  # Modules and kernel conf for obs
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback exclusive_caps=1 video_nr=9 card_label="obs"
  '';
}
