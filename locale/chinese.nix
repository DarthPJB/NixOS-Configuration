# Chinese Input Method Configuration
# Provides fcitx5 with rime input method for Chinese character input
{ config, pkgs, lib, ... }:

{
  # Enable fcitx5 as the input method framework
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    
    # Configure fcitx5 with Chinese input methods
    fcitx5 = {
      # Addons for Chinese input
      addons = with pkgs; [
        # Rime input method - highly customizable Chinese input
        fcitx5-rime
        
        # Chinese addons for fcitx5
        fcitx5-chinese-addons
        
        # Configuration GUI
        fcitx5-configtool
      ];
      
      # Wayland/X11 settings
      settings = {
        globalOptions = {
          "Hotkey/TriggerKeys" = "Control+space";
          "Hotkey/AltTriggerKeys" = "";
          "Hotkey/EnumerateInputForwardKey" = "";
          "Hotkey/EnumerateInputBackwardKey" = "";
          "Hotkey/PreviousPage" = "Page_Up";
          "Hotkey/NextPage" = "Page_Down";
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
    
    # Configuration tool
    fcitx5-configtool
    
    # Additional tools
    fcitx5-gtk
    fcitx5-qt
  ];
}
