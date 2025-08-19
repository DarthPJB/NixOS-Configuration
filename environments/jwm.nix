{ config, pkgs, ... }:

{
  services.picom = {
    enable = true;
    backend = "glx";
    #experimentalBackends = true;
    vSync = true;
    #refreshRate = 60; # Enforce 60 FPS target
    settings = {
      shadow = false;
      fading = false;
      blur = false;
      unredir-if-possible = true;
#      glx-no-stencil = true;
#      glx-no-rebind-pixmap = true;
#      detect-transient = true;
#      detect-client-leader = true;
#      use-damage = true;
      vsync-use-glfinish = true; # Optimize VSync for ARM
    };
  };
  programs.dconf.enable = true;
  environment.systemPackages =
    [
      pkgs.neovim
      pkgs.firefox
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
  #  environment.etc = {
  #    "system.jwmrc" = {
  #      text = ''
  #        <?xml version="1.0"?>
  #        <JWM>
  #          <!-- Keybinding for terminal -->
  #          <Key key="T" mask="CA">exec:alacritty</Key>
  #          <!-- Menu configuration -->
  #          <RootMenu>
  #            <Menu label="Applications">
  #              <Program label="Alacritty" icon="alacritty.png">alacritty</Program>
  #            </Menu>
  #            <Program label="volume mixer" icon="sound.png">pavucontrol</Program>
  #            <Program label="Exit" icon="exit.png">jwm -exit</Program>
  #          </RootMenu>
  #          <!-- Optional: Window behavior -->
  #          <FocusOnClick>true</FocusOnClick>
  #          <SnapMode>border</SnapMode>
  #          <MoveMode>opaque</MoveMode>
  #          <ResizeMode>opaque</ResizeMode>
  #        </JWM>
  #      '';
  #
  #    # The UNIX file mode bits
  #    mode = "0440";
  #  };
  #};

  # Define the "guest" user
  users.users.guest = {
    isSystemUser = true;
    group = "users";
    home = "/home/guest"; # Set a home directory
    createHome = true;
    password = "home";
  };
}
