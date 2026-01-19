{ config, lib, pkgs, ... }:

let
  cfg = config.services.gitolite;
in
{
  options.services.gitolite.enable = lib.mkEnableOption "Gitolite Git hosting";
  services.openssh = {

       settings = {

         # Gitolite user (22 only)
         extraConfig = ''
         Match User deploy
           Port 22
           PermitRootLogin no
           PasswordAuthentication = no
         '';
       };
     };
  config = lib.mkIf cfg.enable {
    users.users.git = {
      isSystemUser = true;
      group = "git";
      home = "/bulk-storage/git-repos";
      shell = pkgs.gitolite;
      openssh.authorizedKeys.keys = [ builtins.readFile ./public_key/id_ed25519_master.pub ];
    };

    users.groups.git = { };

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
