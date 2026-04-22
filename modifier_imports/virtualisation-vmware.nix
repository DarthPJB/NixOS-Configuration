{ config, pkgs, ... }:
{
  networking.firewall.trustedInterfaces = [ "virbr0" ];

  virtualisation.vmware.host = {
    enable = true;
    extraConfig = ''
       # Allow unsupported device's OpenGL and Vulkan acceleration for guest vGPU
      mks.gl.allowUnsupportedDrivers = "TRUE"
      mks.vk.allowUnsupportedDevices = "TRUE"
    '';
  };
  boot.kernelParams = [ "transparent_hugepage=never" ];
}
