# machines/arm-builder/default.nix
# Minimal headless ARM builder — cross-compiled from x86_64
# Reuses display-2's WireGuard identity (10.88.127.42) for zero hub-side reconfiguration
{ pkgs
, config
, lib
, self
, hostname
, ...
}:
{
  # Cross-compilation: build on x86_64, run on aarch64
  nixpkgs.buildPlatform = "x86_64-linux";

  imports = [
    ../../configuration.nix
    ../../modules/enable-wg-topology.nix
    ../../environments/lean-kernel.nix
  ];

  system.name = "${hostname}";

  # SD card root filesystem — label-based, never raw UUID (lesson from display-2 failure)
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  sdImage.compressImage = false;

  enableWgTopology.enable = true;

  # Headless kernel params — serial console for debug, no video output
  boot = {
    kernelParams = [
      "console=ttyS1,115200n8"
      "cma=128M"
    ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  # Wired ethernet at boot — no wpa_supplicant (reduces cross-compile complexity)
  networking.interfaces.eth0.useDHCP = lib.mkDefault true;

  # SSH for nixinate deployment and management
  services.openssh.enable = true;
}
