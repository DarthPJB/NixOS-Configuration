{ config, pkgs, lib, ... }:
let inherit (builtins) readFile;
in {
  services.samba-wsdd.enable =
    true; # make shares visible for windows 10 clients
  networking.firewall.allowedTCPPorts = [
    5357 # wsdd
  ];
  networking.firewall.allowedUDPPorts = [
    3702 # wsdd
  ];
  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      bind interfaces only = yes
      interfaces virbr0
      workgroup = WORKGROUP
      server string = smbnix
      netbios name = smbnix
      security = user 
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      hosts allow = 192.168.122. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = John88
    '';
    shares = {
      public = {
        path = "/bulk-storage/public-share";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "John88";
        "force group" = "users";
      };
      #      private = {
      #        path = "/mnt/Shares/Private";
      #        browseable = "yes";
      #        "read only" = "no";
      #        "guest ok" = "no";
      #        "create mask" = "0644";
      #        "directory mask" = "0755";
      #        "force user" = "username";
      #        "force group" = "groupname";
    };
  };
}
