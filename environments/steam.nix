{ config
, pkgs
, unstable
, pkgs_llm
, ...
}:

{
  programs.steam = {
    package = unstable.steam;
    enable = true; # you probably already have this
    extraCompatPackages = [ pkgs_llm.proton-ge-bin unstable.proton-ge-bin ];
  };

  # Nice-to-have for any game (highly recommended for SE)
  programs.gamemode.enable = true; # Feral's gamemode
  environment.systemPackages = [
    pkgs_llm.prismlauncher
    unstable.vintagestory
  ];

  # Register prismlauncher:// and curseforge:// URL scheme handlers
  # so browsers can hand off OAuth callbacks to PrismLauncher
  xdg.mime.enable = true;
  environment.etc."xdg/mimeapps.list".text = ''
    [Default Applications]
    x-scheme-handler/prismlauncher=org.prismlauncher.PrismLauncher.desktop
    x-scheme-handler/curseforge=org.prismlauncher.PrismLauncher.desktop
  '';
}
