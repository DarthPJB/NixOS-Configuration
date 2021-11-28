{ config, pkgs, ... }:
{
  nix = {
   trustedUsers = [ "root" "John88" ];
   package = pkgs.nixUnstable;
   extraOptions = ''
     experimental-features = nix-command flakes
   '';
  };
}
