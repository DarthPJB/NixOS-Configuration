{ pkgs, config, lib, self, hostname, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../services/dynamic_domain_gandi.nix
      ../../modules/enable-wg.nix
      ../../server_services/game_servers/space-engineers.nix
    ];
  environment.vpn =
    {
      enable = true;
      postfix = 52;
      # privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
    };
  services.space-engineers-servers = 
  {
    enable = true;
    launchOptions = "-console";
  };
  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1"; # or "nodev" for efi only

  environment.systemPackages = with pkgs;
    [
      pkgs.steamcmd
    ];
}

