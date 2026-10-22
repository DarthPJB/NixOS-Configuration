{ config
, pkgs
, unstable
, ...
}:
{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    #  pkgs.firefox
    pkgs.obsidian
    pkgs.vivaldi
    pkgs.chromium
    pkgs.brave
    pkgs.jq
    pkgs.ffmpeg-full
  ];

  # Browsers render dark by default. The system already reports
  # prefers-color-scheme: dark (org.gnome.desktop.interface.color-scheme =
  # prefer-dark via programs.dconf + xdg.portal); these lock each browser's own
  # UI/theme to dark so it does not depend on per-profile mode state. librewolf
  # is provided by programs.firefox (wrapped) and reads the same policies.json.
  programs.firefox = {
    enable = true;
    package = pkgs.librewolf;
    preferences."ui.systemUsesDarkTheme" = 1;
  };
  programs.chromium = {
    enable = true;
    initialPrefs."ui.systemUsesDarkTheme" = 1;
  };

  services = {
    syncthing = {
      enable = false;
      user = "John88";
      group = "users";
      dataDir = "/home/pokej";
    };
  };
}
