{ fqdn }: { pkgs, ... }:
{
  services.uwsgi = {
    enable = true;
    user = "public";
    group = "nginx";
    plugins = [ "cgi" "python3" ];

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


  systemd.services.uwsgi =
    {
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

  users.extraUsers.public =
    {
      extraGroups = [ "git" "nginx" ];
      isSystemUser = true;
      group = "users";
    };

  services.nginx.virtualHosts."${fqdn}" = {
    forceSSL = true;
    useACMEHost = "johnbargman.net";
    root = "${pkgs.cgit}/cgit";
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
        chown -R public:nginx /bulk-storage/cgit
      '';
    };

  environment.etc."cgitrc".text = ''
    virtual-root=/

    cache-size=1000
    cache-root=/bulk-storage/cgit

    root-title=~/projects
    root-desc=You got overburned, now face the ${fqdn}
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
