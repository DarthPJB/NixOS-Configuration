{ config, pkgs, lib, ... }:

{

  systemd.sockets.sshd = {
    # This is the key part: make sshd *always* restart, no matter why it died
    socketConfig = {
      Restart = "always"; # restart on any exit (clean or crash)
      RestartSec = "60"; # wait 1 minute between restarts
    };

    # make sure it never gives up; burn the freaking CPU down with failures; at this point it's life or death.
    upheldBy = [ "sockets.target" ];
    after = [ "wiregaurd-wireg0.target" ];
    startLimitIntervalSec = 5;
    startLimitBurst = 3;
  };

  # Enable the OpenSSH daemon.
  services = {
    openssh = {
      enable = true;
      startWhenNeeded = lib.mkDefault true;
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
        AllowUsers = [ "John88" ];
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
