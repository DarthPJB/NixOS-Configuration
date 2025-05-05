{ config, pkgs, ... }:

{
  # Set your time zone.
  time.timeZone = "Etc/UTC";

  #  Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "uk";
  };

  # Configure keymap in X11
  services.xserver.xkb.layout = "gb";
}
