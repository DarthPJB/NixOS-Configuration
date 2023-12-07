{ config, pkgs, ... }:
{
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.l33 = {
    isNormalUser = true;
    name = "l33";
    description = "l33";
    createHome = true;
    home = "/home/l33";
    hashedPassword = "$6$irFKKFRDPP$H5EaeHornoVvWcKtUBj.29tPvw.SspaSi/vOPGc3GG2bW//M.ld3E7E3XCevJ6vn175A/raHvNIotXayvMqzz0";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGcZrafX+y1V7Q1lSZUSSR6R0ouIPuYL1KCAZw6kOsqe l33@nixos" ];
    extraGroups = [ "wheel" "vboxusers" "dialout" "networkManager" ]; # Enable ‘sudo’ for the user.
    packages = [
      pkgs.firefox
      #pkgs.atom
      pkgs.cmatrix
      pkgs.element-desktop
      pkgs.firefox
      pkgs.pnmixer
      pkgs.conky
      pkgs.nextcloud-client
      pkgs.sl
      pkgs.cmatrix
      pkgs.networkmanagerapplet
      #pkgs.bpytop
    ];
  };
}
