{ pkgs, config, lib, self, hostname, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../services/dynamic_domain_gandi.nix
      ../../modules/enable-wg.nix
    ];
  environment.vpn =
    {
      enable = true;
      postfix = 52;
      # privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
    };

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1"; # or "nodev" for efi only

  # Configure network connections interactively with nmcli or nmtui.
  #networking.networkmanager.enable = true

}

