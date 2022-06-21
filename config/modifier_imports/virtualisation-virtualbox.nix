{ config, pkgs, ... }:
{
   virtualisation.virtualbox.host.enable = true;
   users.extraGroups.vboxusers.members = [ "John88" ];
   nixpkgs.config.allowUnfree = true;
   virtualisation.virtualbox.host.enableExtensionPack = true;
}
