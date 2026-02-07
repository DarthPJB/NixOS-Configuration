{ config, pkgs, lib, ... }:
{

  programs.ssh.enableAskPassword = false;
  programs.gnupg.agent =
    {
      pinentryPackage = pkgs.pinentry-tty;

      enable = true;
      enableSSHSupport = true;
    };
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.John88 = {
    isNormalUser = true;
    uid = 1108;
    name = "John88";
    description = "Eighty Eight";
    createHome = true;
    home = "/home/pokej";
    hashedPassword = "$6$irFKKFRDPP$H5EaeHornoVvWcKtUBj.29tPvw.SspaSi/vOPGc3GG2bW//M.ld3E7E3XCevJ6vn175A/raHvNIotXayvMqzz0";
    openssh.authorizedKeys.keys = [ "${lib.readFile ../secrets/public_keys/JOHN_BARGMAN_ED_25519.pub}" ];
    extraGroups = [ "wheel" "libvirtd" "video" "vboxusers" "dialout" "disk" "networkManager" ]; # Enable ‘sudo’ for the user.
  };
}
