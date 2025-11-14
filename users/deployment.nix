{ config, pkgs, lib, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.deploy = {
    isNormalUser = true;
    uid = 1110;
    name = "deploy";
    description = "deploy connection user";
    createHome = true;
    home = "/tmp/deploy";
    openssh.authorizedKeys.keys = [ "${lib.readFile ../public_key/id_ed25519_master.pub}" ];
    extraGroups = [ "wheel" ];
  };
  security.sudo.extraRules = [
    {
      users = [ "deploy" ];
      commands = [
        # alright here's the down low. 
        {
          command = "ALL"; #If you can get my SSH key, login into this user, and run sudo rm -rf /*, I'm dead.
          options = [ "NOPASSWD" ]; # That also means getting my key, password, breaking rainbow-curves and pretty much already being root... so.. it's fine.
        }
      ];
    }
  ];
}
