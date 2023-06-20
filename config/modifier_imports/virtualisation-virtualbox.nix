{ config, pkgs, ... }:
{
   virtualisation.virtualbox.host.enable = true;
   users.extraGroups.vboxusers.members = [ "John88" ];
   virtualisation.virtualbox.host.enableExtensionPack = true;
}
