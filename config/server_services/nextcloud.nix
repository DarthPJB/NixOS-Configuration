{ config, pkgs, ... }:
let
  inherit (builtins) readFile;
in
{
  age.secrets.nextcloud_password_file = 
  { 
    file = ../../secrets/nextcloud_password_file.age;
    owner = "nextcloud";
    group = "nextcloud";
    mode = "770";
  };
  age.secrets.nextcloud_s3_key =
  {
    file = ../../secrets/nextcloud_s3_key.age;
    owner = "nextcloud";
    group = "nextcloud";
    mode = "770";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.nextcloud = 
  {
    enable = true;                   
    package = pkgs.nextcloud25;
    hostName = "nextcloud.johnbargman.com";
    enableImagemagick = true;
    maxUploadSize = "50G";
    config =
    {
      adminpassFile = config.age.secrets.nextcloud_password_file.path;
      objectstore.s3 = 
      {
        autocreate = true;
        bucket = "nextcloud-darthpjb";
        enable = true;
        hostname = "s3.eu-central-003.backblazeb2.com";
        key = "003e3241026f9950000000001";
        secretFile = config.age.secrets.nextcloud_s3_key.path;
      };
    };

  };

  services.nginx.virtualHosts."nextcloud.johnbargman.com" = {
    extraConfig = "fastcgi_read_timeout 86400;\n";
  };
  services.phpfpm.pools.nextcloud = {
    phpOptions = "php_admin_value[max_input_time] = 86400\n
    php_admin_value[max_execution_time] = 86400\n
    php_admin_value[upload_max_filesize] = 16G
    php_admin_value[post_max_size] = 16G";
  }; 
}
