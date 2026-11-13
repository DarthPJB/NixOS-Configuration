# Deployment Validation — Tracking Record (2026-11-12)

> **Protocol (user directive):** the user deploys each system **manually**.
> The agent **must not attempt any deployment**. The agent records reported
> results here as they arrive, lists undeployed systems, and rectifies any
> errors the user reports.

## Deployment state

- **Tree:** `jb/phase-C` @ `6c02f87` (working tree clean; config content =
  `6bd3863`, the docs commit changes no `.nix`)
- **Pre-deploy evidence (agent-verified, read-only):** golden sweep **20/20**,
  structure checks green, `check-ci` green, fmt/deadnix clean, `ci.yml`
  byte-identical
- **Mayo** `ec28ae3` · **nix-github-ci** `d7641a2` · **gaming-host-1 child**
  `1d93d90` — all pushed

## Deployment record

| Machine | Status | Date | Notes |
|---|---|---|---|
| **LINDA** | ✅ **SUCCESS** | 2026-11-12 | user-deployed (first validation of the full secret-sauce state) |
| alpha-one | ⬜ pending | | |
| alpha-three | ⬜ pending | | |
| arm-builder | ⬜ pending | | aarch64 (native runner deploy path) |
| cortex-alpha | ⬜ pending | | hub — exercises genFirewall/genDns/genNginx/genWireguard heavily |
| display-1 | ⬜ pending | | |
| display-2 | ⬜ pending | | |
| gaming-host-1 | ⬜ pending | | child-flake consumption (extendModules + schema) — second-most sensitive after LINDA |
| local-nas | ⬜ pending | | monitoring host — first live re-provision of the mayo-generated dashboards |
| pillar-of-autum | ⬜ pending | | |
| print-controller | ⬜ pending | | |
| remote-builder | ⬜ pending | | in-house binary cache host |
| remote-worker | ⬜ pending | | ad-hoc nginx surface |
| terminal-nx-01 | ✅ **SUCCESS** | 2026-11-12 | user-deployed |
| terminal-zero | ⬜ pending | | |

## Not deployment targets (excluded from the manual sweep)

| Config | Why excluded |
|---|---|
| `arm-bootstrap`, `x86-bootstrap` | image builders — no deploy app; produce install images, not switched systems |
| `bargman-greeter-vm` | QEMU test VM (run apps only: `bargman-greeter-vm`, `-serial`) |
| `cluster-box` | **external ownership** (dlyon / Malayalam) — parent holds deploy metadata only; deploy only if intentionally exercising the passthrough, not part of "our" fleet sweep |
| `beta-one` | has `nixosConfigurations` but **no nixinate deploy app** (minimal profile, no deploy metadata) — deployable only via explicit `nixos-rebuild --flake .#beta-one`; flag if it should be in scope |
| dormant: `alpha-two`, `storage-array`, `display-0` | in `dormantConfigurations` only — excluded from `nixosConfigurations` by design (not deployable) |

## Error protocol

1. User reports an error verbatim (deploy output / eval failure / build failure).
2. Agent diagnoses against the golden (a config error from these phases shows
   as an eval/build failure — goldens remain sacrosanct; **regeneration is
   never the fix** unless the user orders an intentional config change).
3. Fix lands as a commit on `jb/phase-C`; gates re-run (fmt, deadnix,
   structure, affected goldens); user re-deploys.
4. Result recorded above.

## Sign-off

Completed when all 15 targets are ✅ (or explicitly waived by the user).
