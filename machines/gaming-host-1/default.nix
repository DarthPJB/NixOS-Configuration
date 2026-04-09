{ pkgs, config, lib, self, hostname, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../services/dynamic_domain_gandi.nix
      ../../modules/enable-wg.nix
      ../../server_services/game_servers/space-engineers.nix
      ../../server_services/game_servers/dragonwilds.nix
    ];
  environment.vpn =
    {
      enable = true;
      postfix = 52;
      # privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
    };
  virtualisation.docker.enable = true;
  services.dragonwilds-server.enable = true;
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

