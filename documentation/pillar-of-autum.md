# pillar-of-autum — Assimilation & Deployment Workflow

> **Last updated:** 2026-08-27
> **Status:** Configuration implemented + validated. Awaiting first nixinate deployment.
> **Machine:** `pillar-of-autum` (ASUS NUC14RVH-B, Intel Core Ultra 5 125H)
> **Spelling:** `pillar-of-autum` — **NOT** `pillar-of-autumn`. The extra `n` is a known
> misspelling and must not appear in code, topology, goldens, or commits.

This document is the **record of actions and method of completion** for the first
"proven" assimilator-probe assimilation. It doubles as the runbook for the follow-up
nixinate deployment. Companion planning document: `planning-pillar-of-autum.md`.

---

## 1. Purpose

`pillar-of-autum` is the first machine assimilated end-to-end via the
**assimilator-probe x86-bootstrap** workflow. Its initial configuration is a
**minimal librex11 (XLibre X11) headed system**, similar in shape to `alpha-one`
(i3 + lightdm), built on the existing `@flake.nix` infrastructure.

**Intended future purpose** (per `documentation/ai-stack.md`, "Future Expansion →
Additional backends"): an **AI inference backend** for the fleet LiteLLM gateway,
alongside LINDA and cluster-box.

---

## 2. Hardware Identification (Probe Discovery)

The assimilator-probe was deployed via the generic `x86-bootstrap` raw-disk image
(USB boot, GRUB EFI removable). Discovery followed the standard protocol
(`documentation/x86-bootstrap-deployment-workflow.md`, Stage 2):

| Step | Command | Result |
|------|---------|--------|
| mDNS discovery | `avahi-resolve -n x86-bootstrap.local` | `10.88.128.150` (IPv4), `fe80::8aae:ddff:fe66:70ff` (IPv6) |
| Service enumeration | `avahi-browse -a -t` | `x86-bootstrap [88:ae:dd:66:70:ff] _workstation._tcp` |
| Host key pre-check | `grep 10.88.128.150 ~/.ssh/known_hosts` | `[10.88.128.150]:1108 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE5fWYYizH6kYupOXVB0Eq7qCl68dUkySNdvFEBeW9zo` |
| SSH (inspect, read-only) | `ssh -p 1108 inspect@10.88.128.150` | Banner: "ASSIMILATOR PROBE … Awaiting assimilation." |

**Hardware captured** (read-only `inspect` access, port 1108):

| Attribute | Value |
|-----------|-------|
| Chassis | ASUS NUC14RVH-B (mini-PC) |
| CPU | Intel Core Ultra 5 125H, 18 cores (Meteor Lake, integrated Arc graphics) |
| RAM | 16 GiB |
| Boot medium | `sda` — 118.1 GiB USB flash drive |
| └ `/boot` (ESP) | `sda1`, 1 GiB vfat, UUID `12CE-A600` |
| └ swap | `sda2`, 8 GiB, UUID `851d149e-df1d-4dea-9253-fb64340d714d` |
| └ `/` (root) | `sda3`, 11 GiB ext4, UUID `793f5bea-fb84-4c96-a832-3a8b287a760a` |
| Target storage | `nvme0n1` — 238.5 GiB addlink M.2 PCIe NVMe (pre-existing partitions, unmounted) |
| Wired NIC | `enp86s0`, MAC `88:ae:dd:66:70:ff` |
| WiFi NIC | `wlo1`, MAC `00:d7:6d:e0:5f:83` |
| OS (probe) | NixOS 26.05.20260724.597283a, kernel 6.18.39 |
| machine-id | `7bdcbf4385dd4d489e4bf86fc5dafd0b` |

The partition UUIDs above were read from `/dev/disk/by-uuid` on the running probe and
are the source of truth for `machines/pillar-of-autum/hardware-configuration.nix`.

---

## 3. Configuration Implementation (Completed)

The following files were created/modified to implement the system configuration on the
existing `@flake.nix` infrastructure:

| File | Action | Purpose |
|------|--------|---------|
| `machines/pillar-of-autum/hardware-configuration.nix` | **created** | Probe hardware scan: USB boot layout (by UUID), initrd modules, Intel microcode |
| `machines/pillar-of-autum/default.nix` | **created** | Minimal librex11 headed system: i3 + lightdm (via `i3wm_darthpjb.nix`), WG topology, GRUB EFI removable (mirrors bootstrap), Intel graphics |
| `topology/pillar-of-autum.json` | **created** | Planar topology: `wg` plane peer_id **110** (10.88.127.110), `cortex-alpha.lan` plane peer_id **150** (10.88.128.150, interface `enp86s0`) |
| `secrets/public_keys/host_keys/pillar-of-autum.pub` | **created** | Device SSH host public key (archived from probe, Stage 3) |
| `secrets/public_keys/wireguard/wg_pillar-of-autum_pub` | **created** | WireGuard public key |
| `secrets/private_keys/wireguard/wg_pillar-of-autum` | **created** | WireGuard private key, age-encrypted to John88 + host (secrix) |
| `flake.nix` | **modified** | Registered `pillar-of-autum = mkX86_64 "pillar-of-autum" { … }` with `xlibre-overlay` extraModules |
| `goldens/pillar-of-autum.json` | **created** | Golden test reference (ground truth) |

### 3.1 librex11 (XLibre X11) wiring

"librex11" is the **XLibre X11** server (community fork of X.org X11). It is provided
by the existing `xlibre-overlay` flake input (already used by LINDA) and passed through
`extraModules` in `flake.nix` (flake inputs cannot be referenced from a machine
config's `imports`):

```nix
pillar-of-autum = mkX86_64 "pillar-of-autum" {
  host = topoIp "pillar-of-autum";
  extraModules = [
    xlibre-overlay.nixosModules.overlay-xlibre-xserver      # xorg-server → xlibre-xserver
    xlibre-overlay.nixosModules.overlay-all-xlibre-drivers  # X11 drivers
  ];
};
```

Verified applied: `services.xserver.terminateOnReset = false` (set by the overlay) and
28 nixpkgs overlays present.

### 3.2 Headed environment (similar to alpha-one)

`machines/pillar-of-autum/default.nix` imports `environments/i3wm_darthpjb.nix`
(i3 + lightdm + bargman greeter + picom), the same headed stack as `alpha-one`, but
**without** alpha-one's NVIDIA driver, opencode-fleet, or the heavy environment
modules (steam, code, neovim, etc.) — hence "minimal". Intel integrated graphics use
the default modesetting driver (`hardware.graphics.enable = true`).

### 3.3 Bootloader

The config mirrors the bootstrap image's **GRUB EFI removable** bootloader
(`efiInstallAsRemovable = true`, `canTouchEfiVariables = false`) so the first
nixinate `switch` activates cleanly on the existing ESP. A permanent-install
bootloader migration (systemd-boot on the NVMe) is a documented follow-up
(see `planning-pillar-of-autum.md`, Phase 3).

---

## 4. Validation Performed (Completed)

| Check | Command | Result |
|-------|---------|--------|
| Config evaluates | `nix eval … .config.networking.hostName` | `"pillar-of-autum"` |
| WireGuard enabled | `… .config.networking.wireguard.enable` | `true` (10.88.127.110/32, hub peer cortex-alpha) |
| X server + i3 + lightdm | `… .config.services.xserver.{enable,windowManager.i3.enable,displayManager.lightdm.enable}` | all `true` |
| XLibre overlay applied | `… .config.services.xserver.terminateOnReset` | `false` |
| Golden generated | `nix run .#dump-config -- pillar-of-autum \| jq -S . > goldens/pillar-of-autum.json` | 85 KB |
| Golden matches | `nix run .#validate-goldens -- pillar-of-autum` | ✓ matches |
| Topology coverage | `lib/golden_coverage.nix` | 100% (12/12), no missing |
| Topology registry | `lib/topology/mkRegistry.nix` | 0 errors, 0 warnings |

**Note on git tracking:** Nix flakes only see git-tracked paths. New files required
`git add -N <path>` (intent-to-add) before `nix eval`/`nix run` could resolve them.

---

## 5. Deployment Workflow (Follow-up — nixinate)

This is the runbook for the first "proven" deployment. It mirrors
`documentation/x86-bootstrap-deployment-workflow.md` Stages 5–7.

### Pre-deployment checklist

- [ ] Probe still reachable: `avahi-resolve -n x86-bootstrap.local` → `10.88.128.150`
- [ ] SSH works: `ssh -p 1108 inspect@10.88.128.150 "hostname"` → `x86-bootstrap`
- [ ] Golden passes: `nix run .#validate-goldens -- pillar-of-autum`
- [ ] WG keys present: `ls secrets/public_keys/wireguard/wg_pillar-of-autum_pub`
- [ ] Host key archived: `ls secrets/public_keys/host_keys/pillar-of-autum.pub`

### Stage A — Deploy over LAN (temporary)

1. **Point flake.nix at the device's LAN IP** (temporary):
   ```nix
   pillar-of-autum = mkX86_64 "pillar-of-autum" {
     host = "10.88.128.150";   # TEMPORARY: LAN IP (was: topoIp "pillar-of-autum")
     …
   };
   ```
2. **Deploy with nixinate** (switches the running USB system):
   ```bash
   nix run .#pillar-of-autum --option builders '' -- switch
   ```
3. **Reset flake.nix** to the WireGuard IP:
   ```nix
   host = topoIp "pillar-of-autum";   # back to 10.88.127.110
   ```
4. **Commit and push** the reset.

### Stage B — Verify

1. **WireGuard connectivity:** `ping 10.88.127.110`
2. **SSH on WG:** `ssh -p 1108 deploy@10.88.127.110`
3. **Hostname changed:** `ssh -p 1108 inspect@10.88.127.110 "hostname"` → `pillar-of-autum`
4. **Headed session:** confirm lightdm greeter + i3 session on the attached display
   (XLibre X11 server running).
5. **Golden re-check:** `nix run .#validate-goldens -- pillar-of-autum`

### Stage C — Post-deployment

- [ ] Add `pillar-of-autum` to `~/.ssh/config` (inspect + deploy entries, port 1108)
- [ ] Record the deployment in `shared_updates.md`
- [ ] Proceed to `planning-pillar-of-autum.md` Phase 2 (AI backend) / Phase 3 (NVMe)

---

## 6. Key Differences from Prior Deployments

| Aspect | arm-bootstrap (ARM) | x86-bootstrap → pillar-of-autum |
|--------|---------------------|----------------------------------|
| Image format | SD card (`.img`) | Raw disk (`.raw`, GPT, USB) |
| SSH port | 22 | 1108 |
| Module source | Raw NixOS modules | assimilator-probe nixosModule |
| Cross-compilation | Yes (x86_64 → aarch64) | No (native x86_64) |
| Bootloader | extlinux (Raspberry Pi) | GRUB EFI removable (`EFI/BOOT/BOOTX64.EFI`) |
| Diagnostics | None | Boot-time `/run/diagnostics/hardware.json` |
| X server | — | **XLibre (librex11)** via xlibre-overlay |
| Determinate Nix | Not in bootstrap | Not in bootstrap (native build on first deploy) |

---

## 7. Lessons / Notes

1. **Spelling discipline:** `pillar-of-autum` (no extra `n`). Enforced in code comments,
   topology `hostname`, and golden.
2. **Git intent-to-add:** New files must be `git add -N` before Nix can see them in a
   flake.
3. **secrix system resolution:** `nix run .#secrix encrypt … -s <host>` resolves the
   host from `nixosConfigurations` — the machine must be registered in `flake.nix`
   **before** its WG private key can be encrypted with `-s <host>`.
4. **Bootloader continuity:** Keep GRUB EFI removable for the first `switch` so the
   existing ESP boots the new kernel without EFI-variable changes.
5. **Read-only inspection:** All probe hardware discovery used the `inspect` user
   (no sudo, port 1108) per the SSH Access Standard.
