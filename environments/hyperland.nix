{ config, pkgs, self, ... }:
{
  programs.hyprland = {
    enable = true;
  #  package = self.inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  # Optional: Enable XWayland for compatibility
  programs.hyprland.xwayland.enable = true;
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
