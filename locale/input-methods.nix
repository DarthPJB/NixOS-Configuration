# Unified Input Methods Configuration
# Supports Chinese (rime) and Thai (IKBAEB-th) input methods via fcitx5
# Keybindings: Super+; or Super+e = Toggle IME, Super+c = Cycle forward, Super+t = Cycle backward
{ config, pkgs, lib, self, ... }:

{
  # Add IKBAEB-th custom Thai keyboard layout
  services.xserver.xkb.extraLayouts = self.inputs.ikbaeb-th.extraLayouts pkgs.stdenv.hostPlatform.system;

  # Configure fcitx5 with multiple input methods
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;

    fcitx5 = {
      addons = with pkgs; [
        # Rime input method for Chinese
        fcitx5-rime

        # Chinese addons for fcitx5 (renamed in newer nixpkgs)
        qt6Packages.fcitx5-chinese-addons

        # GTK and Qt integration
        fcitx5-gtk
        qt6Packages.fcitx5-qt

        # Configuration GUI (renamed in newer nixpkgs)
        qt6Packages.fcitx5-configtool
      ];

      settings = {
        globalOptions = {
          # Toggle fcitx5 on/off (returns to English when off)
          # Using Super+semicolon to avoid conflict with i3's Super+space (floating toggle)
          Hotkey = {
            TriggerKeys = "Super+semicolon,Super+e";
            EnumerateInputForwardKey = "Super+c";
            EnumerateInputBackwardKey = "Super+t";
            PreviousPage = "Page_Up";
            NextPage = "Page_Down";
          };
        };

        # Input method group: English -> Chinese -> Thai
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "keyboard-us";
          };

          # English keyboard (default)
          "Groups/0/Items/0" = {
            Name = "keyboard";
            Layout = "us";
          };

          # Chinese rime input
          "Groups/0/Items/1" = {
            Name = "rime";
            Layout = "";
          };

          # Thai IKBAEB-th layout
          "Groups/0/Items/2" = {
            Name = "keyboard";
            Layout = "ikbatha0";
          };
        };
      };
    };
  };

  # CJK fonts and fontconfig defaults live in environments/general_fonts.nix
  # (single font policy home; keep font packages/defaultFonts together).

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

  # Ensure fcitx5 starts with the graphical session.
  # CRITICAL: launch config.i18n.inputMethod.package (the fcitx5-with-addons
  # wrapper that sets FCITX_ADDON_DIRS) — NOT pkgs.fcitx5, the bare upstream
  # binary, which cannot see rime/chinese addons and silently degrades to
  # keyboard-only. The i18n.inputMethod module provides no unit of its own
  # (xdg autostart only); this unit is the i3 launcher.
  systemd.user.services.fcitx5 = {
    description = "Fcitx5 Input Method";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = lib.getExe config.i18n.inputMethod.package;
      Restart = "on-failure";
    };
  };
}
