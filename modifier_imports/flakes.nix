{ config, pkgs, ... }:
{
  nix = {
    settings.trusted-users = [ "root" "John88" ];
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
}
