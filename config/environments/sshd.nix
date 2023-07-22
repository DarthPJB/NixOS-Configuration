{ config, pkgs, lib, ... }:

{
  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.ports = [ 1108 ];
  services.openssh.permitRootLogin = lib.mkForce "no";
  services.openssh.passwordAuthentication = false;
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 1108 ];
  networking.firewall.allowedUDPPorts = [ ];
}
