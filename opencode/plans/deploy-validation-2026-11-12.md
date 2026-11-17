# Deployment Validation — Tracking Record (2026-11-12)

> **Protocol (user directive):** the user deploys each system **manually**.
> The agent **must not attempt any deployment**. The agent records reported
> results here as they arrive, lists undeployed systems, and rectifies any
> errors the user reports.

## Deployment state

- **Tree:** `jb/phase-C` @ `732db00` (working tree clean). Config content =
  `6bd3863` for every machine except LINDA: `732db00` landed 2026-11-13 after
  the initial records — LINDA hardware-config only (root-fill mitigation:
  `/` tmpfs 2G→32G, `/etc/opencode` + `/etc/opencode2` bind mounts to
  speed-storage). All other machine configs are byte-identical to `6c02f87`.
  Pre-deploy evidence below was verified at `6c02f87`.
- **Pre-deploy evidence (agent-verified, read-only):** golden sweep **20/20**,
  structure checks green, `check-ci` green, fmt/deadnix clean, `ci.yml`
  byte-identical
- **Mayo** `ec28ae3` · **nix-github-ci** `d7641a2` · **gaming-host-1 child**
  `1d93d90` — all pushed

## Deployment record

| Machine | Status | Date | Notes |
|---|---|---|---|
| **LINDA** | ✅ **SUCCESS** | 2026-11-12 | user-deployed (first validation of the full secret-sauce state) |
| alpha-one | ✅ **SUCCESS** | 2026-11-16 | user-deployed |
| alpha-three | ✅ **SUCCESS** | 2026-11-16 | user-deployed |
| arm-builder | ⬜ pending | | aarch64 (native runner deploy path) |
| cortex-alpha | ⬜ pending | | hub — exercises genFirewall/genDns/genNginx/genWireguard heavily |
| display-1 | ⬜ pending | | |
| display-2 | ⬜ pending | | |
| gaming-host-1 | ✅ **SUCCESS** | 2026-11-16 | user-deployed — child-flake consumption (extendModules + schema) validated in production |
| local-nas | ✅ **SUCCESS** | 2026-11-13 | user-deployed — monitoring host; first live re-provision of the mayo-generated dashboards (secret-sauce plan R2 validated in production) |
| pillar-of-autum | ✅ **SUCCESS** | 2026-11-16 | user-deployed |
| print-controller | ✅ **SUCCESS** | 2026-11-13 | user-deployed |
| remote-builder | ⬜ pending | | in-house binary cache host — ⚠️ cache-serve 504s diagnosed 2026-11-14 (see Diagnosis section); deploy-gate flag on dual TLS terminations |
| remote-worker | ⬜ pending | | ad-hoc nginx surface |
| terminal-nx-01 | ✅ **SUCCESS** | 2026-11-12 | user-deployed |
| terminal-zero | ✅ **SUCCESS** | 2026-11-13 | user-deployed (config unaffected by `732db00` — LINDA-only change) |

## Not deployment targets (excluded from the manual sweep)

| Config | Why excluded |
|---|---|
| `arm-bootstrap`, `x86-bootstrap` | image builders — no deploy app; produce install images, not switched systems |
| `bargman-greeter-vm` | QEMU test VM (run apps only: `bargman-greeter-vm`, `-serial`) |
| `cluster-box` | **external ownership** (dlyon / Malayalam) — parent holds deploy metadata only; deploy only if intentionally exercising the passthrough, not part of "our" fleet sweep |
| `beta-one` | has `nixosConfigurations` but **no nixinate deploy app** (minimal profile, no deploy metadata) — deployable only via explicit `nixos-rebuild --flake .#beta-one`; flag if it should be in scope |
| dormant: `alpha-two`, `storage-array`, `display-0` | in `dormantConfigurations` only — excluded from `nixosConfigurations` by design (not deployable) |

## Diagnosis — cache serve failures (remote-builder) 2026-11-14

> **STATUS: KNOWN ISSUE (user ruling 2026-11-16).** No remediation ruled —
> recorded and cross-posted to AGENTS.md Current Issues. The R1–R5 option
> table below stays OPEN for a future ruling. Deploy of remote-builder is
> gated on the dual-TLS-termination flag regardless.

**Scope: DIAGNOSED, NOT RECTIFIED** (user directive). Evidence gathered
read-only over `ssh deploy@remote-builder -p 1108` + local topology/config
reads + one live `curl` probe.

### Request path (verified)

```
nix client (e.g. `nix run .#alpha-three`, parallel NAR fetches)
→ https://cache.johnbargman.net  (DNS: 10.88.128.1 = cortex-alpha, topology DNS)
→ cortex-alpha nginx TLS → proxy_to 10.88.127.51:5001 (WireGuard)
→ remote-builder nix-serve (Starman PreFork, patched nix-serve.psgi)
→ per-request child: `nix store dump-path` (NAR stream)
```

### Root cause — worker starvation × 60s proxy timeout × slow uplink

1. **5-worker synchronous server.** Starman PreFork runs the stock 5 workers;
   each NAR request occupies one worker for the entire stream AND forks a
   `nix store dump-path` child (observed 34 MB RSS each, 4+ min elapsed for
   large paths — nvidia firmware/modules, webkitgtk).
2. **Parallel demand > service capacity.** `nix` fetches many paths at once;
   requests beyond 5 sit unread in the socket backlog. Evidence: 10+ ESTAB
   connections with `Recv-Q 373` (a complete HTTP request, never accepted),
   `lastrcv` aging 20–50 s, while all 5 workers stream to other peers.
3. **nginx default `proxy_read_timeout` 60s.** cortex-alpha's vhost sets
   `proxy_connect_timeout 5s` only — read timeout stays at the 60 s default.
   Queued requests never get response headers within 60 s → **504 Gateway
   Time-out** (exactly the client log's HTML body).
4. **Retry storm sustains saturation.** nix retries 5× with 1–95 ms backoff —
   every 504 re-enters an already-full queue (client log: cascade of 504s
   across ~13 parallel copies).
5. **Abandoned streams waste the worker.** When nginx times out it closes the
   upstream; the still-running `dump-path` child hits `error: write of N
   bytes: Broken pipe` / `Starman/Server.pm … Connection timed out` (journal,
   Nov 13 18:56 & 20:18) and keeps the worker busy until the write fails.
6. **Uplink is the throughput bound.** WG path delivers ~1–4 MB/s
   (`delivery_rate` in `ss -tinp`); a worker slot is held for minutes per big
   NAR, so starvation persists long after the burst starts.

**Probe evidence (2026-11-14 ~13:21 UTC):** `GET /nix-cache-info` — a tiny
static file — returned **200 in 35.35 s** (connect 2 ms, TLS 21 ms → 35 s is
pure queue wait); three follow-up probes exceeded 60 s and timed out.

### State notes (as observed)

- **`nix-serve` systemd unit: `active (running)`** — up since 2026-11-13
  20:18 UTC (the 3 restarts that day are deploy-related, clean start/stop;
  no OOM, no crash-loop, `Restart=always` never fired). The "failed state"
  is **functional** (504 storm), not unit-level.
- **Actually-failed units on the box: 5× `github-runner-*`** (disgust-1,
  entropy-is-origin-1, hate-filled-1/2, rat-infested-1) — dead since Nov 5:
  `Runner version v2.336.0 is deprecated and cannot receive messages`.
  Separate fault; blocks CI on this host. **Needs a runner package bump.**
- Resources are healthy: `/nix` 55 % (306G/590G), RAM 16 G (nix-serve cgroup
  peak 4.3 G, mostly stream page cache), no OOM ever.
- Store GC disabled by design (cache retains closures) — not a factor.
- **remote-builder's own nginx has NO cache vhost live** (only the default
  localhost server) — the machine's `services.nginx` + ACME block is
  undeployed (machine is ⬜ pending). The topology path via cortex-alpha is
  what actually serves. ⚠️ **Deploy-gate flag:** when remote-builder IS
  deployed, DNS (topology → 10.88.128.1 cortex-alpha) and the machine-local
  vhost would be two competing terminations for the same name — ruling needed
  before that deploy.

### Remediation options (NOT executed — for user ruling)

| # | Option | Effect | Cost |
|---|---|---|---|
| R1 | Raise `proxy_read_timeout`/`proxy_send_timeout` (e.g. 1 h) on the `cache.johnbargman.net` vhost (cortex-alpha) | Kills 504s; long NARs complete | Retries still storm the queue; workers still hold minutes-long streams |
| R2 | Increase Starman workers (patch `nix-serve` ExecStart `--workers N`) | More parallel dumps | Each worker = a `nix` child + stream; WG link stays the bound |
| R3 | Lower client `http-connections` fleet-wide | Smooths bursts | Slows every fetch |
| R4 | Serve NARs at nginx layer (X-Accel-Redirect from nix-serve) | Removes PSGI bottleneck entirely | Architectural change; new generator/service work |
| R5 | Move cache traffic off WG bottleneck (LAN/direct route) | Raises throughput floor | Network topology change |

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
