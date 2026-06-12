{ pkgs
, config
, lib
, self
, hostname
, ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../services/dynamic_domain_gandi.nix
    ../../modules/enable-wg-topology.nix
    ../../server_services/game_servers/space-engineers.nix
    ../../server_services/game_servers/dragonwilds.nix
    ../../server_services/game_servers/windrose.nix
    ../../server_services/game_servers/terratech.nix
    ../../server_services/game_servers/minecraft-curseforge.nix
    (import ../../services/acme_server.nix { fqdn = "gaming-host-1.johnbargman.net"; })
  ];
  enableWgTopology.enable = true;
  virtualisation.docker.enable = true;
  services.dragonwilds-server.enable = true;
  services.windrose-docker = {
    enable = true;
    serverName = "Fox and Wolf";
    serverNote = "Co-op adventures await - join the pack!";
    openFirewall = true;
  };
  services.terratech-worlds-server = {
    enable = true;
    uid = 29987;
    gid = 29987;
    password = "godlet";
    openFirewall = true;
    map = "Phaeton";
  };

  # Keep both TerraTech UDP ports open while clients transition:
  # current intended port is 7777; 7778 remains a compatibility fallback.
  networking.firewall.allowedUDPPorts = [
    7777
    7778
  ];

  services.space-engineers-docker = {
    enable = false; # disabled — port 8080 conflict with squaremap
    instanceName = "KJTNewWorld";
    worldName = "Star System";
    #    gameMode = "SURVIVAL";
    publicIP = "65.108.141.32";
    openFirewall = true;
  };

  #users.users.deploy.openssh.authorizedKeys = [ "" ];
  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1"; # or "nodev" for efi only

  environment.systemPackages = with pkgs; [ ];

  # ── Nginx reverse proxy for squaremap ──────────────────────────────
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."gaming-host-1.johnbargman.net" = {
      forceSSL = true;
      useACMEHost = "gaming-host-1.johnbargman.net";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
      };
    };
  };

  # Allow nginx through the firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # ── Minecraft CurseForge Servers ────────────────────────────────────
  services.minecraft-curseforge.all-the-mons = {
    enable = true; # re-enabled 2026-06-06
    pack = pkgs.minecraft-curseforge-all-the-mons;
    acceptEula = true;
    maxMemory = "8G";
    minMemory = "4G";
    gamePort = 25565;
    rconPort = 25575;
    rconPassword = "allthemons"; # TODO: change this or move to secrets
    openFirewall = true;

    # squaremap web map viewer
    enableSquaremap = true;
    squaremapPort = 8080;
    openSquaremapFirewall = true; # accessible on all interfaces (WireGuard + public)
    ops = [
      { uuid = "a02323f6-eaf1-44d2-8d37-d260c914cb00"; name = "John88"; level = 4; bypassesPlayerLimit = true; }
      { uuid = "d23e3eb2-954b-4544-ad3d-982f0ef495aa"; name = "boxfox"; level = 4; bypassesPlayerLimit = true; }
    ];
    serverProperties = {
      "allow-flight" = true;
      "motd" = "in the waters of nurse joy a hero blooms";
      "max-tick-time" = 180000;
      "simulation-distance" = 8;
      "view-distance" = 20;
      "max-players" = 8;
      "difficulty" = "normal";
      "gamemode" = "survival";
      "level-seed" = "4240772663413292738";
    };
  };
}
