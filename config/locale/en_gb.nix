{ config, pkgs, ... }:

{
  # Set your time zone.
  time.timeZone = "Europe/London";

  #  Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "uk";
  };

  # Configure keymap in X11
  services.xserver.layout = "gb";
}
