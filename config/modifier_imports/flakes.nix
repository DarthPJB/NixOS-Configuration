{ config, pkgs, ... }:
{
  nix = {
    settings.trusted-users = [ "root" "John88" ];
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
}
