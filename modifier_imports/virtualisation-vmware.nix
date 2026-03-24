{ config, pkgs, ... }:
{
  networking.firewall.trustedInterfaces = [ "virbr0" ];

  virtualisation.vmware.host = 
  {
    enable = true;
  boot.kernelParams = [ "transparent_hugepage=never" ];
  virtualisation.vmware.host.extraConfig = ''
  # Allow unsupported device's OpenGL and Vulkan acceleration for guest vGPU
  mks.gl.allowUnsupportedDrivers = "TRUE"
  mks.vk.allowUnsupportedDevices = "TRUE"
'';
}
