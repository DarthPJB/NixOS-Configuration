{ config, pkgs, ... }:

{
  programs.dconf.enable = true;
  environment.systemPackages =
    [
      pkgs.neovim
      pkgs.chromium
      pkgs.pavucontrol
      pkgs.alacritty
    ];
  services = {
    xserver =
      {
        monitorSection = ''
          Option "PreferredMode" "1920x1080_60.00"
        '';
        enable = true;
        windowManager.jwm = {
          enable = true;
        };
      };
    displayManager = {
      sddm.enable = true;
      autoLogin = {
        enable = true;
        user = "guest";
      };
    };
  };

  # Define the "guest" user
  users.users.guest = {
    isSystemUser = true;
    group = "users";
    home = "/home/guest"; # Set a home directory
    createHome = true;
    password = "home";
  };
}
