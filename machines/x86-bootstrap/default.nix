# machines/x86-bootstrap/default.nix
# Generic x86_64 bootstrap image — reusable for ALL x86_64 devices
# Purpose: boot on x86_64 hardware, get on network, be discoverable, accept deployment
# This is NOT a machine config — it's a one-shot deployment vehicle.
#
# Consumes assimilator-probe module for SSH, networking, discovery, diagnostics.
# No encrypted assets — secrets are provisioned post-assimilation.
#
# Build: nix build .#nixosConfigurations.x86-bootstrap.config.system.build.diskoImages
# Docs: documentation/x86-bootstrap-deployment-workflow.md
#
# NOTE: Module imports (assimilator-probe.nixosModules.default, user modules)
# are in flake.nix — not here. Flake inputs cannot be referenced in imports
# because _module.args are resolved after imports, causing infinite recursion.
{ pkgs
, config
, lib
, ...
}:
{
  # Assimilator-probe options — bootstrap defaults
  # No host key (generated on first boot), no WireGuard, no WiFi
  assimilator = {
    hostname = "x86-bootstrap";
    sshAllowUsers = [ "John88" "deploy" "inspect" ];
    sshAuthorizedKeys = [
      (lib.readFile ../../secrets/public_keys/JOHN_BARGMAN_ED_25519.pub)
    ];
    fleetKeys = [
      (lib.readFile ../../secrets/public_keys/JOHN_BARGMAN_ED_25519.pub)
    ];
    inspectAuthorizedKeys = [
      (lib.readFile ../../secrets/public_keys/INSPECT_ED_25519.pub)
    ];
  };

  # USB/UEFI bootstrap: firmware looks for /EFI/BOOT/BOOTX64.EFI on removable
  # media. The previous image wrote grub.cfg + kernels to the ESP but never
  # installed an EFI binary (grub.efiSupport was false, device was empty).
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
    timeoutStyle = "menu";
  };
  boot.loader.efi = {
    canTouchEfiVariables = false;
    efiSysMountPoint = "/boot";
  };
  boot.loader.timeout = 5;
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
    "boot.shell_on_fail"
    "loglevel=7"
  ];
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "uas"
    "sd_mod"
    "sr_mod"
    "usbhid"
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "ata_piix"
  ];
  hardware.enableRedistributableFirmware = true;
}
