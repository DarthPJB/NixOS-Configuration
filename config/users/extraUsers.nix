{ config, pkgs, ... }:
{
  users.extraUsers.walkerjp123={
        uid=112;
        isNormalUser = true;
        extraGroups = ["wheel" "vboxusers"];
        home = "/home/walker";
  };

  users.extraUsers.darthpjb={
        uid=1000;
        isNormalUser = true;
        extraGroups = ["wheel" "vboxusers" "dialout" "networkManager"];
        home = "/home/john";
        openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZ0k7iuFr6stY9bjMQRvpm+pgOH//2pIgZbfO218SdhZDsMxjWtAHqli9zBzGLVuIVsQlMtkhGoztdJNKNga0urZKghlZbKlaThThcdCMnJPx2MbQjU+gXsxaKzdHhMMKBEOZuVyAAmeu/lYT8/jtq3/GLQMV13gfXa02TTr+MEJ0pjFb1Q2SPItMqUSGIVVj1tJusvEteUOyaJI7jOHx+c8SNarg4/dmlCFLuWz5mug55k2j+bz2FeSdcOB+sb6lgkyl/rmsSay5N0v48JVHfWQFi9+w+UArFp2NPQE8kv0fPdIxTK1A7S7aaPR8yExVJFKZV5M/QoOu6mQx4ph1iSb6kiTNS0r8PsjXmzYrEnu1K/TqDBdQk/CbDdKZqHx/HJbPa73b/6Bkbo8pWVqB3Q/uW11oPOvbnBkLUVFNmqg7kyH3kl+Xrmy4FZRPoVldAkFrlQYApRFk3cZysoSSkMbwyq/BZqVvFi66STK/Njy7pzXatqNDdMRMavOG5/dE= DarthPJB@nixos" ];
  };

  users.extraUsers.user223219B=
  {
    uid=1001;
    isNormalUser = true;
    extraGroups = ["wheel" "dialout"];
    home = "/home/colin";
  };
}
