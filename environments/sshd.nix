{ config, pkgs, lib, ... }:

{

  systemd.services.sshd = {
    wantedBy = [ "multi-user.target" ];

    # This is the key part: make sshd *always* restart, no matter why it died
    serviceConfig = {
      Restart = "always"; # restart on any exit (clean or crash)
      RestartSec = "300"; # wait 5 minutes (300 seconds) between restarts
    };

    # make sure it never gives up; burn the freaking CPU down with failures; at this point it's life or death.
    startLimitIntervalSec = 0; # 0 = no limit (disable start-rate limiting)
    startLimitBurst = 0;
  };

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
