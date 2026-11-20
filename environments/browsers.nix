{ config
, pkgs
, unstable
, lib
, ...
}:
{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    #  pkgs.firefox
    pkgs.obsidian
    pkgs.vivaldi
    pkgs.chromium
    pkgs.jq
    pkgs.ffmpeg-full
  ]
  # brave was removed from nixpkgs_unstable (LINDA's surface: "no committers
  # to unblock security issues"); keep it only where the pin still carries it.
  ++ lib.optional (builtins.tryEval pkgs.brave).success pkgs.brave;

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
