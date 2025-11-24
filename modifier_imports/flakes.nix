{ config, pkgs, ... }:
{
  nix.settings.experimental-features = [ "flakes" ];
}
