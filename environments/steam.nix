{
  config,
  pkgs,
  unstable,
  ...
}:

{
  programs.steam = {
    enable = true; # you probably already have this
    extraCompatPackages = with unstable; [ proton-ge-bin ];
  };

  # Nice-to-have for any game (highly recommended for SE)
  programs.gamemode.enable = true; # Feral's gamemode
  environment.systemPackages = [
    unstable.prismlauncher
    unstable.vintagestory
  ];
}
