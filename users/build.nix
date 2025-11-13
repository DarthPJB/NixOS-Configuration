{ config, pkgs, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.build = {
    isNormalUser = true;
    uid = 1108;
    name = "build";
    description = "non-privlaged builder";
    createHome = true;
    home = "/tmp/builder";
    hashedPassword = "$6$irFKKFRDPP$H5EaeHornoVvWcKtUBj.29tPvw.SspaSi/vOPGc3GG2bW//M.ld3E7E3XCevJ6vn175A/raHvNIotXayvMqzz0";
    openssh.authorizedKeys.keys =
      [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5 darthpjb@gmail.com"
      ];
    extraGroups = [
      # No ]; 
      };
      }
