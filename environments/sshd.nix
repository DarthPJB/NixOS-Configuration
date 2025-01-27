{ config, pkgs, lib, ... }:

{
  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.ports = [ 1108 22 ];
  services.openssh.settings.PermitRootLogin = lib.mkForce "no";
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.hostKeys = [{
    path = "/etc/ssh/ssh_host_ed25519_key";
    type = "ed25519";
  }];
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 1108 22 ];
  networking.firewall.allowedUDPPorts = [ ];
}
