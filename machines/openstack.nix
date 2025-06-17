{ config, lib, pkgs, modulesPath, ... }:
{
  services.openssh.ports = [ 22 ];
  networking.firewall.allowedTCPPorts = [ 22 ];
}
