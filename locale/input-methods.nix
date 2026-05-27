# Unified Input Methods Configuration
# Supports Chinese (rime) and Thai (IKBAEB-th) input methods via fcitx5
# Keybindings: Super+c = Chinese, Super+t = Thai
{ config, pkgs, lib, self, ... }:

{
  # Add IKBAEB-th custom Thai keyboard layout
  services.xserver.extraLayouts = self.inputs.ikbaeb-th.extraLayouts pkgs.system;

  # Configure fcitx5 with multiple input methods
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;

    fcitx5 = {
      addons = with pkgs; [
        # Rime input method for Chinese
        fcitx5-rime
        
        # Chinese addons for fcitx5
        fcitx5-chinese-addons
        
        # GTK and Qt integration
        fcitx5-gtk
        fcitx5-qt
        
        # Configuration GUI
        fcitx5-configtool
      ];

      settings = {
        globalOptions = {
          # Primary trigger: Super+c for Chinese input
          "Hotkey/TriggerKeys" = "Super+c";
          "Hotkey/AltTriggerKeys" = "";
          "Hotkey/EnumerateInputForwardKey" = "";
          "Hotkey/EnumerateInputBackwardKey" = "";
          "Hotkey/PreviousPage" = "Page_Up";
          "Hotkey/NextPage" = "Page_Down";
        };

        # Input method groups
        inputMethod = {
          # Default group
          "Groups/0" = {
            "Name" = "Default";
            "Default Layout" = "ikbatha0";
            "DefaultIM" = "rime";
          };

          # Thai keyboard layout
          "Groups/0/Items/0" = {
            "Name" = "keyboard";
            "Layout" = "ikbatha0";
          };

          # Chinese rime input
          "Groups/0/Items/1" = {
            "Name" = "rime";
            "Layout" = "";
          };
        };

        # Rime configuration
        rime = {
          "rime" = {
            "schema" = "luna_pinyin";
          };
        };
      };
    };
  };

  # Install Chinese fonts
  fonts = {
    packages = with pkgs; [
      # Noto Sans CJK - comprehensive Chinese/Japanese/Korean font
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif

      # WenQuanYi fonts - another popular CJK font
      wqy_microhei
      wqy_zenhei

      # Source Han Serif - Adobe's CJK font
      source-han-serif

      # Source Han Sans - Adobe's sans-serif CJK font
      source-han-sans
    ];

    # Enable fontconfig for CJK fonts
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Noto Serif CJK SC" "Noto Serif" ];
        sansSerif = [ "Noto Sans CJK SC" "Noto Sans" ];
        monospace = [ "Noto Sans Mono CJK SC" "Noto Sans Mono" ];
      };
    };
  };

  # Set environment variables for fcitx5
  environment.sessionVariables = {
    # Enable fcitx5 for GTK applications
    GTK_IM_MODULE = "fcitx";

    # Enable fcitx5 for Qt applications
    QT_IM_MODULE = "fcitx";

    # Enable fcitx5 for XIM
    XMODIFIERS = "@im=fcitx";

    # Enable fcitx5 for SDL applications
    SDL_IM_MODULE = "fcitx";

    # Input method module for GLFW (for some games)
    GLFW_IM_MODULE = "ibus";
  };

  # Ensure fcitx5 starts with the graphical session
  systemd.user.services.fcitx5 = {
    description = "Fcitx5 Input Method";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.fcitx5}/bin/fcitx5";
      Restart = "on-failure";
    };
  };

  # Install fcitx5 and related packages
  environment.systemPackages = with pkgs; [
    # Core fcitx5
    fcitx5
    
    # Rime input method
    fcitx5-rime
    
    # Chinese addons
    fcitx5-chinese-addons
    
    # GTK and Qt integration
    fcitx5-gtk
    fcitx5-qt
    
    # Configuration tool
    fcitx5-configtool
  ];
}
