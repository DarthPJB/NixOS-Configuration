{ config, pkgs, self, ... }:
{
  programs.hyprland = {
    enable = true;
    #   package = self.inputs.hyprland.packages.${pkgs.system}.hyprland;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Enable XDG portals for screensharing and file pickers
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-hyprland ];
    wlr.enable = true;
  };

  # Hint apps (e.g., Electron-based) to prefer Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  services.displayManager.defaultSession = "hyprland";
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        gtk-theme = "Adwaita";
        icon-theme = "Flat-Remix-Red-Dark";
        font-name = "Noto Sans Medium 11";
        document-font-name = "Noto Sans Medium 11";
        monospace-font-name = "Noto Sans Mono Medium 11";
      };
    }
  ];
}
