{ config, pkgs, self, ... }:
let
  inherit (builtins) readFile;
  fqdn = "nextcloud.johnbargman.net";
  fqdn2 = "nextcloud.johnbargman.com";
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
      package = pkgs.nextcloud31;
      hostName = "${fqdn}";
      https = true;
      enableImagemagick = true;
      maxUploadSize = "50G";
      settings.enabledPreviewProviders = [
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
          dbtype = "sqlite";
          adminpassFile = config.secrix.system.secrets.nextcloud_password_file.decrypted.path;
          objectstore.s3 =
            {
              verify_bucket_exists = true;
              bucket = "nextcloud-darthpjb";
              enable = true;
              hostname = "s3.eu-central-003.backblazeb2.com";
              key = "003e3241026f9950000000001";
              secretFile = config.secrix.system.secrets.nextcloud_s3_key.decrypted.path;
            };
        };

    };
  services.nginx.virtualHosts.${fqdn2} = {
    forceSSL = true;
    useACMEHost = "johnbargman.com";
    globalRedirect = "nextcloud.johnbargman.net";
    extraConfig = "fastcgi_read_timeout 86400;\n";
  };
  services.nginx.virtualHosts.${fqdn} = {
    forceSSL = true;
    useACMEHost = "johnbargman.net";
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
