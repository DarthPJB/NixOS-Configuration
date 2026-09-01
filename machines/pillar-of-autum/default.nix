# machines/pillar-of-autum/default.nix
#
# pillar-of-autum — ASUS NUC14RVH-B (Intel Core Ultra 5 125H)
#
# First machine assimilated via the assimilator-probe x86-bootstrap workflow.
# Initial intention: a minimal librex11 (XLibre X11) headed system, similar in
# shape to alpha-one (i3 + lightdm), deployed over the probe via nixinate.
#
# NOTE: spelling is "pillar-of-autum" — NOT "pillar-of-autumn". The extra n is
# a known misspelling and must not appear in code, topology, or goldens.
#
# XLibre X11 (librex11) is provided by the xlibre-overlay flake input, passed
# through extraModules in flake.nix (flake inputs cannot be referenced from
# this file's imports — see machines/x86-bootstrap/default.nix header).
#
# Future purpose: AI inference backend for the fleet LiteLLM gateway
# (see documentation/ai-stack.md — "Additional backends: pillar-of-autum").
{ config
, lib
, pkgs
, self
, hostname
, ...
}:
{
  imports = [
    # Include the results of the hardware scan (probe hardware, USB boot layout).
    ./hardware-configuration.nix
    # Topology-driven WireGuard client (wg plane, hub = cortex-alpha).
    ../../modules/enable-wg-topology.nix
    # Headed environment: i3 + lightdm + bargman greeter (same as alpha-one).
    ../../environments/i3wm_darthpjb.nix
  ];

  enableWgTopology.enable = true;

  # ── Headed system (librex11 / XLibre X11) ─────────────────────
  # The X server itself is overlaid to xlibre-xserver by
  # xlibre-overlay.nixosModules.overlay-xlibre-xserver (flake.nix).
  # Intel Core Ultra 5 125H integrated graphics — modesetting driver.
  # lightdm + i3 are enabled by environments/i3wm_darthpjb.nix (as on alpha-one).
  hardware.graphics.enable = true;

  # ── Bootloader ────────────────────────────────────────────────
  # Mirror the assimilator-probe bootstrap image (GRUB EFI removable) so the
  # first nixinate `switch` activates cleanly on the existing ESP. The
  # firmware boots EFI/BOOT/BOOTX64.EFI; a permanent-install bootloader
  # migration (systemd-boot on the NVMe) is a documented follow-up.
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
    "loglevel=7"
  ];

  hardware.enableRedistributableFirmware = true;
}
