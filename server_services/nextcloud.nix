{ config, pkgs, self, ... }:
let
  inherit (builtins) readFile;
in
{
  secrix.system.secrets = {
    nextcloud_password_file.encrypted.file = ../secrets/nextcloud_password_file;
    nextcloud_password_file.decrypted =
      {
        user = "nextcloud";
        group = "nextcloud";
        mode = "770";
      };
    nextcloud_s3_key.encrypted.file = ../secrets/nextcloud_s3_key;
    nextcloud_s3_key.decrypted =
      {
        user = "nextcloud";
        group = "nextcloud";
        mode = "770";
      };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.nextcloud =
    {
      configureRedis = true;
      enable = true;
      package = pkgs.nextcloud28;
      hostName = "nextcloud.johnbargman.com";
      https = true;
      enableImagemagick = true;
      maxUploadSize = "50G";
      extraOptions.enabledPreviewProviders = [
        "OC\\Preview\\BMP"
        "OC\\Preview\\GIF"
        "OC\\Preview\\JPEG"
        "OC\\Preview\\Krita"
        "OC\\Preview\\MarkDown"
        "OC\\Preview\\MP3"
        "OC\\Preview\\OpenDocument"
        "OC\\Preview\\PNG"
        "OC\\Preview\\TXT"
        "OC\\Preview\\XBitmap"
        "OC\\Preview\\HEIC"
      ];
      config =
        {
          adminpassFile = config.secrix.system.secrets.nextcloud_password_file.decrypted.path;
          objectstore.s3 =
            {
              autocreate = true;
              bucket = "nextcloud-darthpjb";
              enable = true;
              hostname = "s3.eu-central-003.backblazeb2.com";
              key = "003e3241026f9950000000001";
              secretFile = config.secrix.system.secrets.nextcloud_s3_key.decrypted.path;
            };
        };

    };

  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    forceSSL = true;
    enableACME = true;
    extraConfig = "fastcgi_read_timeout 86400;\n";
  };
  # services.phpfpm.pools.nextcloud = {
  #  user = "nextcloud";
  #  phpOptions = "php_admin_value[max_input_time] = 86400\n
  #  php_admin_value[max_execution_time] = 86400\n
  #  php_admin_value[upload_max_filesize] = 16G\n
  #  php_admin_value[post_max_size] = 16G\n";
  #};
}
