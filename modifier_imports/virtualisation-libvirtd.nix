{ config, pkgs, ... }:
{
  networking.firewall.trustedInterfaces = [ "virbr0" ];
  virtualisation.libvirtd =
    {
      enable = true;
      qemu = {
        swtpm.enable = true;
        #        ovmf = {
        #          enable = true;
        #          packages = [ pkgs.OVMFFull.fd ];
        #        };
        runAsRoot = false;
      };
      onBoot = "ignore";
      onShutdown = "shutdown";
    };
}
