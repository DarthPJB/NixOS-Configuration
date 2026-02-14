{ config, pkgs, unstable, ... }:

{
  programs.steam.enable = true;
  environment.systemPackages = [ unstable.prismlauncher  unstable.vintagestory ];
}
