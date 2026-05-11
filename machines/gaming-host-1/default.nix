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
    ../../modules/enable-wg.nix
    ../../server_services/game_servers/space-engineers.nix
    ../../server_services/game_servers/dragonwilds.nix
    ../../server_services/game_servers/windrose.nix
    ../../server_services/game_servers/terratech.nix
  ];
  environment.vpn = {
    enable = true;
    postfix = 52;
    # privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
  };
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
  };

  # Keep both TerraTech UDP ports open while clients transition:
  # current intended port is 7777; 7778 remains a compatibility fallback.
  networking.firewall.allowedUDPPorts = [
    7777
    7778
  ];

  services.space-engineers-docker = {
    enable = true;
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
}
