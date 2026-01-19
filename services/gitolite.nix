{ config, lib, pkgs, ... }:
  services.openssh = {
         # Gitolite user (22 only)
         extraConfig = ''
         Match LocalPort 22 User git Address 10.88.127.1/24
           PermitRootLogin no
           PasswordAuthentication = no
          
         Match LocalPort 22
           DenyUsers *
         '';
     };
       services.gitolite = {
    enable = true;
    user = "git";
    group = "git";
    adminPubkey = builtins.readFile ${self}/public_key/id_ed25519_master.pub;
    extraGitoliteRc = ''
      $RC{UMASK} = 0027;
      $RC{GIT_CONFIG_KEYS} = '.*';
    '';
  };

    #openssh.authorizedKeys.keys = [ builtins.readFile ./public_key/id_ed25519_master.pub ];

    systemd.tmpfiles.rules = [
      "d /bulk-storage/git-repos 0770 git git - -"
    ];
    services.openssh.listenAddresses = [{
      addr = "10.88.127.${builtins.toString config.environment.vpn.postfix}";
      port = 22;
    }];
    environment.systemPackages = [ pkgs.gitolite ];
  };
}
