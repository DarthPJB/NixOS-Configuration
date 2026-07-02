# machines/arm-bootstrap/default.nix
# Generic ARM bootstrap image — reusable for ALL ARM devices
# Purpose: boot on ARM hardware, get on network, be discoverable, accept deployment
# This is NOT a machine config — it's a one-shot deployment vehicle.
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
    ../../modifier_imports/flakes.nix
    ../../users/darthpjb.nix
    ../../users/deployment.nix
    ../../users/inspect.nix
  ];

  # Strip heavy NixOS profiles
  disabledModules = [
    "profiles/all-hardware.nix"
    "profiles/base.nix"
  ];

  # No documentation — bootstrap image, absolute baseline
  documentation = {
    enable = false;
    dev.enable = false;
    man.enable = false;
    info.enable = false;
  };

  # Generic hostname — overridden by deployment
  system.name = "arm-bootstrap";

  # SD card root filesystem — label-based, never raw UUID
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  sdImage.compressImage = false;

  # Open SSH on port 22 — listens on all interfaces (0.0.0.0)
  # IP is DHCP-derived; deploy user for nixinate, inspect for read-only, John88 for console
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    listenAddresses = [
      { addr = "0.0.0.0"; port = 22; }
    ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      AllowUsers = [ "John88" "deploy" "inspect" ];
    };
  };

  # Discovery broadcast — aids in finding the device on the network
  # TODO: mDNS/Avahi discussion pending
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
    hostName = "nixos-bootstrap";
  };

  # Headless kernel params — serial console for debug
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

  # Timezone
  time.timeZone = "Etc/UTC";

  # Wired ethernet at boot — DHCP
  networking.interfaces.eth0.useDHCP = lib.mkDefault true;

  # Firewall — open port 22 for SSH
  networking.firewall.allowedTCPPorts = [ 22 ];
}
