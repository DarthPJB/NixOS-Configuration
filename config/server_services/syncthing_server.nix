{ config, pkgs, lib, ... }:
let
  inherit (builtins) readFile;
in
{
  environment.systemPackages = [ pkgs.rclone];

  # Syncthing ports
  networking.firewall.allowedTCPPorts = [ 8384 22000];
  networking.firewall.allowedUDPPorts = [ 22000 21027];

  age.secrets.futureNAS_s3_key =
  {
    file = ../../secrets/futureNAS_s3_key.age;
    owner = "root";
    group = "root";
    mode = "770";
  };

  environment.etc = 
  {
    "rclone/rclone.conf" = {
      text = ''
        [b2]
        type = b2
        account = 5e0312b4815022568f690915
        key = NOT_the_Password
        hard_delete = true
        versions = false
      '';
      mode = "0644";
    };
  };

  systemd.services.mountNasDir = {
    enable = true;
    description = "Mount media dir";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStartPre = 
      let
        script = pkgs.writeScript "myuser-start" ''
          #!${pkgs.runtimeShell}
          key_id = $(cat ${config.age.secrets.futureNAS_s3_key.path} )
          /run/current-system/sw/bin/mkdir -p /futureNAS
          /run/current-system/sw/bin/sed -i 's/NOT_the_Password/$key_id' /etc/rclone/rclone.conf
        '';
      in "${script}";
      ExecStart = 
      let script = pkgs.writeScript "myuser-start" ''
          #!${pkgs.runtimeShell}
          ${pkgs.rclone}/bin/rclone mount 'b2:futureNAS/' /futureNAS \
            --config=/etc/rclone/rclone.conf \
            --allow-other \
            --allow-non-empty \
            --log-level=INFO \
            --buffer-size=50M \
            --drive-acknowledge-abuse=true \
            --no-modtime \
            --vfs-cache-mode full \
            --vfs-cache-max-size 15G \
            --vfs-read-chunk-size=32M \
            --vfs-read-chunk-size-limit=256M
        '';
      in "${script}";
      ExecStop = "/run/wrappers/bin/fusermount -u /mnt/media";
      Type = "notify";
      Restart = "always";
      RestartSec = "10s";
      Environment = ["PATH=${pkgs.fuse}/bin:$PATH"];
    };
  };

services = {
  syncthing = {
    enable = false;
    dataDir = "/futureNAS";
    configDir = "/futureNAS.config/syncthing";
    overrideDevices = true;     # overrides any devices added or deleted through the WebUI
    overrideFolders = true;     # overrides any folders added or deleted through the WebUI
  };
};
}
