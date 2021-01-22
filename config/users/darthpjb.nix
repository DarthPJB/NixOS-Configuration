
{ config, pkgs, ... }:
{
    imports =
    [
      ../enviroments/i3wm.nix
    ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
   programs.gnupg.agent = {
     enable = true;
    enableSSHSupport = true;
   };

  # TODO: update this with appropriate entries
   services.xserver.windowManager.i3.extraSessionCommands = "sleep 5; conky& nextcloud& pnmixer&  ~/screen_layout.sh";

  # Define a user account. Don't forget to set a password with ‘passwd’.
   users.users.John88 = {
     isNormalUser = true;
     name = "John88";
     description = "Eighty Eight";
     createHome = true;
     home = "/home/pokej";
     hashedPassword = "$6$vWIrHl4Fzv$n9I5isw5aWL4v0ha3z4A1Nf.sRygfmuaOnPq7ji/9cW7w.c.UCdIbwdz6L32vVee2GDOou8tgleJkcl66vPlf/";
     openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZ0k7iuFr6stY9bjMQRvpm+pgOH//2pIgZbfO218SdhZDsMxjWtAHqli9zBzGLVuIVsQlMtkhGoztdJNKNga0urZKghlZbKlaThThcdCMnJPx2MbQjU+gXsxaKzdHhMMKBEOZuVyAAmeu/lYT8/jtq3/GLQMV13gfXa02TTr+MEJ0pjFb1Q2SPItMqUSGIVVj1tJusvEteUOyaJI7jOHx+c8SNarg4/dmlCFLuWz5mug55k2j+bz2FeSdcOB+sb6lgkyl/rmsSay5N0v48JVHfWQFi9+w+UArFp2NPQE8kv0fPdIxTK1A7S7aaPR8yExVJFKZV5M/QoOu6mQx4ph1iSb6kiTNS0r8PsjXmzYrEnu1K/TqDBdQk/CbDdKZqHx/HJbPa73b/6Bkbo8pWVqB3Q/uW11oPOvbnBkLUVFNmqg7kyH3kl+Xrmy4FZRPoVldAkFrlQYApRFk3cZysoSSkMbwyq/BZqVvFi66STK/Njy7pzXatqNDdMRMavOG5/dE= DarthPJB@nixos"];
     extraGroups = [ "wheel" "vboxusers" "dialout" "networkManager" ]; # Enable ‘sudo’ for the user.
     packages = [
    	pkgs.firefox
    	pkgs.atom
    	pkgs.cmatrix
    	pkgs.element-desktop
    	pkgs.firefox
      pkgs.pnmixer
    	pkgs.nextcloud-client
    	pkgs.sl
    	pkgs.cmatrix
    	];
   };
}
