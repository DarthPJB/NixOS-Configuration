{ config, pkgs, lib, ... }:
let
  inherit (builtins) readFile;
  fqdn = "syncthing.johnbargman.com";
  certs = config.security.acme.certs;
  certDirectory = "${certs.${fqdn}.directory}";

in
{
  environment.systemPackages = [ pkgs.rclone pkgs.fuse3 ];

  # Syncthing ports
  networking.firewall.allowedTCPPorts = [ 8384 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  #  security.acme.certs.${fqdn} = {
  #    group = "syncthing-certs";
  #    postRun = "systemctl restart syncthing.service";
  #  };
  #  users.groups.syncthing-cert.members = [ "syncthing" "nginx" ];

  #  services.nginx = {
  #    enable = true;
  #    virtualHosts.${fqdn} = {
  #      listenAddresses = [
  #        config.systemInfo.networks.public.ipv4
  #        config.systemInfo.networks.private.ipv4
  #      ];
  #      useACMEHost = "johnbargman.com";
  #      forceSSL = true;
  #      locations."/".return = "301 https://johnbargman.com";
  #    };
  #  };


  services = {
    syncthing = {
      guiAddress = "0.0.0.0:8384";
      openDefaultPorts = true;
      enable = true;
      user = "syncthing";
      #    cert = "${certDirectory}/fullchain.pem";
      #	key = "${certDirectory}/key.pem";

      dataDir = "/futureNAS";
      configDir = "/syncthing/.config/syncthing";
      overrideDevices = true; # overrides any devices added or deleted through the WebUI
      overrideFolders = true; # overrides any folders added or deleted through the WebUI
      settings = {
        extraOptions.gui = {
          theme = "black";
          user = "DarthPJB";
          password = "A_SAFE_PASSWORD";
        };
        devices = {
          "local-nas" = { id = "YSM4GLR-RVNNKB5-56ICTQG-7WJSIVC-VAYUBIO-ANZCL5W-3JIVSUY-IECJGQQ"; };
          "remote-worker-2" = { id = "OXQM5H4-BF4WOD7-BEM2L75-53YUDKE-MOVNUJU-WA5Q3NT-TO7Q7NI-DEK23AB"; };
        };
        folders = {
          "obisidan-archive" = {
            # Name of folder in Syncthing, also the folder ID
            id = "hb36j-r9ffv";
            path = "/futureNAS/obsidian-archive"; # Which folder to add to Syncthing
            devices = [ "local-nas" "remote-worker-2" ]; # Which devices to share the folder with
          };
          "NAS-ARCHIVE" = {
            # Name of folder in Syncthing, also the folder ID
            id = "gtpsy-rfgv5";
            path = "/futureNAS/remote.worker"; # Which folder to add to Syncthing
            devices = [ "local-nas" "remote-worker-2" ]; # Which devices to share the folder with
          };
          "Camera" = {
            # Name of folder in Syncthing, also the folder ID
            id = "bv6600pro_jmg1-photos";
            path = "/futureNAS/bv6600pro_jmg1-photos"; # Which folder to add to Syncthing
            devices = [ "local-nas" "remote-worker-2" ]; # Which devices to share the folder with
          };
          "default" = {
            # Name of folder in Syncthing, also the folder ID
            id = "default";
            path = "/futureNAS/default"; # Which folder to add to Syncthing
            devices = [ "local-nas" "remote-worker-2" ]; # Which devices to share the folder with
          };
        };
      };

      #TODO: add cert and pem files
    };
  };
  age.secrets.futureNAS_s3_key =
    {
      file = ../../secrets/futureNAS_s3_key.age;
      owner = "root";
      group = "root";
      mode = "600";
    };

  systemd.services.mountNasDir =
    let
      mountpoint = "/futureNAS";
    in
    {
      enable = true;
      description = "Mount media dir";
      wantedBy = [ "multi-user.target" ];
      before = [ "syncthing-init.service" ];
      serviceConfig = {
        ExecStartPre =
          let
            # execute folder preperation and runtime secret transfer (may not be needed with s3fs)
            script = pkgs.writeScript "myuser-start" ''#!${pkgs.runtimeShell}
            ${pkgs.coreutils}/bin/mkdir -p ${mountpoint}
           #/run/current-system/sw/bin/chmod 777 ${mountpoint}
          '';
          in
          "${script}";
        ExecStart =
          let
            # Execute s3fs mount
            # Rip out this rclone shit.
            script = pkgs.writeScript "myuser-start" ''#!${pkgs.runtimeShell}
	    ${pkgs.s3fs}/bin/mount.s3fs -o use_path_request_style -o allow_other -o umask=0002 futureNAS ${mountpoint} -o passwd_file=${config.age.secrets.futureNAS_s3_key.path} -o url=https://s3.eu-central-003.backblazeb2.com -f
          '';
          in
          "${script}";
        ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u ${mountpoint}";
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        Environment = [ "PATH=${pkgs.fuse3}/bin:$PATH" ];
      };
    };
}
