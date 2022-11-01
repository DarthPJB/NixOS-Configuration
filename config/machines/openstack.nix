{ config, lib, pkgs, modulesPath, ... }: 
{
    system.stateVersion = 22.11;
    services.openssh.ports = [ 22 ];
    networking.firewall.allowedTCPPorts = [ 22 ];
}