{ config, pkgs, lib, ... }:

{
  # Enable the OpenSSH daemon.
  services = {
    openssh = {
      enable = true;
      ports = [ 1108 ];
      settings = {
        PermitRootLogin = lib.mkForce "no";
        PasswordAuthentication = false;
        LoginGraceTime = 30;
        MaxAuthTries = 3;
        MaxSessions = 2;
        X11Forwarding = false;
        AllowTcpForwarding = false;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 0;
        KbdInteractiveAuthentication = false;
        AllowUsers = [ "John88" ]; # Replace with actual user(s)
      };
      hostKeys = [{
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }];
    };
  };
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 1108 ];
  networking.firewall.allowedUDPPorts = [ ];
}
