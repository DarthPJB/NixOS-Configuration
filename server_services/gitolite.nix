{ config, pkgs, ... }:
{

  services.openssh.extraConfig = ''
    # Only this block applies to connections on port 22
        Match LocalPort 22
          # Allow only git from the VPN subnet
          AllowUsers git@10.88.127.0/24

          # Explicitly reinforce (optional but clearer)
          PermitRootLogin no
          PasswordAuthentication no
  '';
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [
    80
    22
  ];
  services.openssh.listenAddresses = [
    {
      addr = "10.88.127.${builtins.toString config.environment.vpn.postfix}";
      port = 22;
    }
  ];

  services.uwsgi = {
    enable = true;
    user = "git";
    group = "nginx";
    plugins = [
      "cgi"
      "python3"
    ];

    instance = {
      type = "emperor";
      vassals = {
        cgit = {
          type = "normal";
          master = "true";
          socket = "/run/uwsgi/cgit.sock";
          chmod-socket = 664;
          procname-master = "uwsgi cgit";
          plugins = [ "cgi" ];
          cgi = "${pkgs.cgit}/cgit/cgit.cgi";
        };
      };
    };
  };

  users.users.git = {
    extraGroups = [ "nginx" ];
    isSystemUser = true;
    group = "git"; # primary group
    openssh.authorizedKeys.keyFiles = [ ../secrets/public_keys/JOHN_BARGMAN_ED_25519.pub ];
  };

  systemd.services.uwsgi = {
    serviceConfig.ReadWritePaths = [
      "/bulk-storage/cgit"
    ];
  };

  services.gitolite = {
    enable = true;
    user = "git";
    group = "git";
    adminPubkey = builtins.readFile ../secrets/public_keys/JOHN_BARGMAN_ED_25519.pub;
    extraGitoliteRc = ''
      $RC{UMASK} = 0027;
      $RC{GIT_CONFIG_KEYS} = '.*';
    '';
  };

  services.nginx = {
    enable = true;

    virtualHosts = {

      # Plain HTTP - internal network only (port 80)
      "raw" = {
        listen = [
          {
            addr = "10.88.127.${builtins.toString config.environment.vpn.postfix}";
            port = 80;
          }
        ];

        # Optional: restrict to VPN subnet only
        # addDefaultServer = true;  # if this is the only http vhost

        locations = {
          "/" = {
            extraConfig = ''
              try_files $uri @cgit;
            '';
          };

          "@cgit" = {
            extraConfig = ''
              uwsgi_pass unix:/run/uwsgi/cgit.sock;
              include ${pkgs.nginx}/conf/uwsgi_params;
              uwsgi_modifier1 9;
              uwsgi_read_timeout 600;
            '';
          };
          # Serve all static files under /cgit-static/
          "/cgit-static/" = {
            alias = "${pkgs.cgit}/cgit/";
            extraConfig = ''
              expires 30d;
              add_header Cache-Control "public";
            '';
          };
          # Optional: serve git smart-http (git clone http://...)
          "~ ^/(.*/(HEAD|info/refs|objects|git-upload-pack))$" = {
            extraConfig = ''
              uwsgi_pass unix:/run/uwsgi/cgit.sock;
              include ${pkgs.nginx}/conf/uwsgi_params;
              uwsgi_modifier1 9;
            '';
          };
        };

        # Disable SSL entirely for this vhost
        onlySSL = false;
        enableACME = false;
        forceSSL = false;
      };
    };
  };

  systemd.services.create-cgit-cache = {
    description = "Create cache directory for cgit";
    enable = true;
    wantedBy = [ "uwsgi.service" ];
    serviceConfig = {
      type = "oneshot";
    };
    script = ''
      mkdir -p /bulk-storage/cgit
      chmod -R 750 /bulk-storage/cgit
      chown -R git /bulk-storage/cgit
    '';
  };

  environment.etc."cgitrc".text = ''
    virtual-root=/
    css=/cgit-static/cgit.css
    favicon=/cgit-static/favicon.ico
    logo=/cgit-static/cgit.png
    cache-size=1000
    cache-root=/bulk-storage/cgit

    root-title=~/projects
    root-desc=And so, it begins.
    footer=All rights Reserved, 2026 - John Bargman.
    enable-index-owner=0
    enable-http-clone=0
    noplainemail=1

    max-atom-items=50

    enable-git-config=1
    enable-gitweb-owner=1
    remove-suffix=1

    snapshots=all
    readme=master:README.md
    readme=:readme.md
    readme=:README.mkd
    readme=:readme.mkd
    readme=:README.rst
    readme=:readme.rst
    readme=:README.html
    readme=:readme.html
    readme=:README.htm
    readme=:readme.htm
    readme=:README.txt
    readme=:readme.txt
    readme=:README
    readme=:readme
    readme=:INSTALL.md
    readme=:install.md
    readme=:INSTALL.mkd
    readme=:install.mkd
    readme=:INSTALL.rst
    readme=:install.rst
    readme=:INSTALL.html
    readme=:install.html
    readme=:INSTALL.htm
    readme=:install.htm
    readme=:INSTALL.txt
    readme=:install.txt
    readme=:INSTALL
    readme=:install

    source-filter=${pkgs.cgit}/lib/cgit/filters/syntax-highlighting.py
    about-filter=${pkgs.cgit}/lib/cgit/filters/about-formatting.sh

    project-list=/var/lib/gitolite/projects.list
    scan-path=/var/lib/gitolite/repositories
  '';
}
