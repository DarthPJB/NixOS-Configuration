{ config, pkgs, ... }:
{
   virtualisation = 
   {
      libvirtd = 
      {
         enable = true;
         qemu.ovmf.enable = true;
      };
   };
   users.extraGroups.libvirtd.members = [ "John88" ];
   #networking.nat.enable = true;
   #boot.kernel.sysctl = { "net.ipv4.ip_forward" = 1; };

   #networking.bridges.br0.interfaces = ["enp69s0f0"];
   #programs.dconf.enable = true;
   environment.systemPackages = with pkgs; [ virt-manager ];
   #networking.interfaces.br0 = {
    #useDHCP = false;
    #ipv4.addresses = [{
    #  "address" = "10.0.0.6";
    #  "prefixLength" = 24;
    #}];
  #};
}
