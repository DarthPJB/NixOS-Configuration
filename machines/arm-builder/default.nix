# machines/arm-builder/default.nix
# Minimal headless ARM builder — cross-compiled from x86_64
# Bootstrap image: absolute baseline, no configuration.nix bloat
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
    # configuration.nix is blocked via disabledModules below —
    # commonModules injects it for ALL machines, but we don't need
    # tools.nix (magic-wormhole), monitoring, WiFi, or admin user.
    ../../modules/enable-wg-topology.nix
    # ../../environments/lean-kernel.nix  # INTENTIONALLY OMITTED — needed later for display machines
    ../../environments/sshd.nix
    ../../modifier_imports/flakes.nix
    ../../users/darthpjb.nix
    ../../users/build.nix
    ../../users/deployment.nix
    ../../users/inspect.nix
  ];

  # Block configuration.nix (injected by commonModules at flake level)
  # and heavy NixOS profiles. This eliminates tools.nix, monitoring modules,
  # WiFi config, admin user, and all non-essential packages.
  disabledModules = [
    ../../configuration.nix
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

  system.name = "${hostname}";

  # SD card root filesystem — label-based, never raw UUID (lesson from display-2 failure)
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  sdImage.compressImage = false;

  enableWgTopology.enable = true;

  # Pre-generated SSH host key — deterministic, enables secrix decryption on first boot
  secrix.services.ssh-host-key.secrets.arm-builder-host-key.encrypted.file =
    ../../secrets/host_keys/arm-builder_ssh_host_ed25519;

  # Copy decrypted host key to /etc/ssh before sshd starts
  systemd.services.ssh-host-key-setup = {
    description = "Setup SSH host key from secrix secret";
    wantedBy = [ "sshd.service" ];
    before = [ "sshd.service" ];
    after = [ "secrix-ssh-host-key-secrets.service" ];
    requires = [ "secrix-ssh-host-key-secrets.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /etc/ssh
      cp ${config.secrix.services.ssh-host-key.secrets.arm-builder-host-key.decrypted.path} /etc/ssh/ssh_host_ed25519_key
      chmod 600 /etc/ssh/ssh_host_ed25519_key
      # Derive public key from private key
      ${pkgs.openssh}/bin/ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub
    '';
  };

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

  # Timezone — was inherited from configuration.nix/locale, now explicit
  time.timeZone = "Etc/UTC";

  # Wired ethernet at boot — no wpa_supplicant (reduces cross-compile complexity)
  networking.interfaces.eth0.useDHCP = lib.mkDefault true;

  # SSH for nixinate deployment and management
  services.openssh.enable = true;
}
