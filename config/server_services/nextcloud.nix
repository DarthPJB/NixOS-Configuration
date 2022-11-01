{ config, pkgs, ... }:
{

  age.secrets.nextcloud_password_file = 
  { 
    file = ../../secrets/nextcloud_password_file.age;
  };
  age.secrets.nextcloud_s3_key = 
  {
    file = ../../secrets/nextcloud_s3_key.age;
  };
  
  services.nextcloud = 
  {
    enable = true;                   
    package = pkgs.nextcloud24;
    hostName = "nextcloud.johnbargman.com";
    enableImagemagick = true;
    maxUploadSize = "2048M";
    config = {
      adminpassFile = config.age.secrets.nextcloud_password_file.path;
      objectstore.s3 = 
      {
        enable = true;
        hostname = "s3.eu-central-003.backblazeb2.com";
        key = config.age.secrets.nextcloud_s3_key.file;
      };
    };
  };
}