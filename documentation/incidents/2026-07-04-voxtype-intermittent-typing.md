# Incident Report: Voxtype Intermittent Typing & Empty Journal

**Date:** 2026-07-04  
**Host:** LINDA  
**Severity:** Medium — speech-to-text transcription intermittently failed; no diagnostic logging available  
**Status:** Resolved (pending deploy)

---

## Summary

Voxtype daemon ran as `active (running)` (PID 2573557, voxtype-0.7.2 vulkan build)
but transcription was intermittent. `journalctl --user -u voxtype` returned empty,
blocking diagnosis.

---

## Root Causes (verified live)

1. **/dev/uinput ACL-gated by logind**: No `uinput` group existed; dotool's
   `/dev/uinput` access relied on logind's udev `uaccess` ACL which is revoked
   on session state change (VT switch, screen lock, multi-seat). When revoked,
   dotool silently fell back to clipboard and typing did not land at cursor.
   Verified: `getfacl /dev/uinput` showed only `user:John88:rw-` (ACL), no group.

2. **driver_order included Wayland-only wtype**: voxtype's auto-detected chain
   `[wtype, dotool, ydotool, clipboard]` always tried `wtype` first (fails on
   X11), adding latency and a failure point before dotool. `voxtype setup check`
   reported "Text will be typed via clipboard — Only clipboard mode available".
   Valid driver variants: `wtype`, `eitype`, `dotool`, `ydotool`, `clipboard`,
   `xclip`. Note: `xdotool` is NOT a valid voxtype driver.

3. **Environment=PATH clobber**: Module's narrow `PATH=which:xclip` overrode
   NixOS's default PATH in the unit file. dotool only worked because the
   process inherited a rich PATH from the dbus session environment — fragile.
   A `systemctl --user restart voxtype` from a non-desktop login would break
   typing.

4. **No RUST_LOG wired**: voxtype uses `tracing-subscriber` with EnvFilter
   (verified live: `RUST_LOG=voxtype=debug voxtype config` emits debug lines),
   but the module did not surface a `logLevel` option. Default verbosity
   emitted nothing during healthy operation.

5. **modifier_release_timeout_ms=750 too tight**: META+V push-to-talk with
   non-exclusive evdev grab; if META still physically held when dotool
   injected text, i3 swallowed it as a binding. Bumped to 1500ms.

6. **Per-user journald namespace dead** (separate issue):
   `systemd-journald@1108.service` is inactive (dead), socket activation
   not firing, namespace dir `/run/systemd/journal.1108/` doesn't exist.
   systemd-258 / NixOS-25.11 regression affecting all user units, not just
   voxtype. Tracked separately as Phase 6.

---

## Resolution

### denton-glasses module (commit ef09a1b, merged to main as 941f825)

- Add `uinput.enable` option (default true): creates `uinput` group + udev rule
  `KERNEL=="uinput", GROUP="uinput", MODE="0660"` + `DeviceAllow=/dev/uinput rw`
- Add `output.driverOrder` option: set to `[dotool xclip]` on LINDA (skips
  Wayland-only `wtype`, uninstalled `ydotool`/`eitype`)
- Add `logLevel` option: maps to `RUST_LOG=voxtype=<level>` in service env
  (default "warn", LINDA uses "info")
- Add `globalArgs` option: clap global flags before `daemon` subcommand
- Drop `Environment=PATH=` override (was clobbering NixOS default PATH)
- Fix `DeviceAllow=/dev/dri/` (trailing slash for systemd directory glob)
- Bump `modifier_release_timeout_ms` default 750→1500
- Add `pre_type_delay_ms=50` default (virtual keyboard init time)

### NixOS-Configuration (commit 21a602b on fix/voxtype-linda-config)

- Set `services.voxtype.output.driverOrder = [ "dotool" "xclip" ];`
- Set `services.voxtype.logLevel = "info";`
- Set `services.voxtype.uinput.enable = true;` (explicit)
- Remove stale `primaryIndex = 1` comment (fixed in gen 327, June 28)
- Fix `libpulse` comment → `alsa-lib` (package links alsa-lib, not libpulse)
- denton-glasses flake input temporarily patched to local path for validation;
  revert to `git+https://gitlab.com/mecha-team-zero/denton-glasses.git` after
  denton-glasses main is pushed and flake.lock is re-updated

---

## Open Questions

1. Why is `systemd-journald@1108.service` not activating? (Phase 6 investigation)
2. Should the module support `EVIOCGRAB` (exclusive evdev grab) to eliminate
   the modifier-release race entirely? (upstream voxtype feature request)
3. The pre-existing golden drift on LINDA (ratty/i3/rofi packages, node_exporter
   port 3100→9100) is unrelated to this fix and needs separate golden
   regeneration.

---

## References

- `environments/denton-glasses.nix` — voxtype consumer config (LINDA)
- `denton-glasses/modules/voxtype.nix` — module source (fix branch)
- `documentation/incidents/2026-06-28-voxtype-gpu-primaryIndex.md` — prior incident
- `documentation/research/gpu-primary-selection-nixos.md` — GPU research
- Live inspection report (this session): voxtype PID 2573557, vxtype-0.7.2 vulkan
