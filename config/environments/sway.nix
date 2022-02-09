{ config, pkgs, ... }:

{
  hardware.opengl.enable = true;
  # Enable the X11 windowing system.
  services.xserver.enable = true;
  programs.sway =
  {
    enable = true;
    wrapperFeatures.gtk = true; # so that gtk works properly
    #extraSessionCommands = "wpa_gui & nextcloud & parsecd & blueman-applet &";
    extraPackages = with pkgs;
    [
      swaylock
      swayidle
      wl-clipboard
      mako # notification daemon
      alacritty # Alacritty is the default terminal in the config
      dmenu # Dmenu is the default in the config but i recommend wofi since its wayland native
    ];
  };
}
