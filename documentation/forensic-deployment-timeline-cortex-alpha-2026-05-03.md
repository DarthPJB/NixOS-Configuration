# Forensic Deployment Timeline: `cortex-alpha` (2026-04-22 to 2026-04-27)
**Created:** 2026-05-03
**Purpose:** Identify when WireGuard likely regressed while Tailscale remained functional, and mark which periods are safe for golden baselines.

---

## Executive Finding
The most likely WireGuard failure window begins at:
- **`3b50922` (2026-04-22 17:35)**

Primary probable causes in that commit line:
1. **Placeholder WireGuard public keys** (`publicKey = "placeholder-..."`)
2. **Hub imported client module** (`../../modules/enable-wg.nix` in `machines/cortex-alpha/default.nix`)
3. **Peer/host naming mismatches with silent peer drops** in topology peer generation

This explains your observed pattern:
- **Tailscale up**
- **WireGuard broken**

---

## Timeline with Risk Levels

### GREEN — Known good pre-refactor deployment behavior
### `9103ebf` — 2026-04-22 07:45 — "cortex alpha is now tailscale hub"
- Scope: adds tailscale UDP GRO tuning only.
- WireGuard architecture still pre-topology.
- **Risk:** LOW (GREEN)

---

### YELLOW — Initial topology introduction (high change volume, not yet proven deploy-safe)
### `fa33e16` — 2026-04-22 10:22 — "initital pass at topology"
- Introduces topology files + initial golden.
- Major architecture transition begins.
- **Risk:** MEDIUM (YELLOW)

### `8dae2b9` — 2026-04-22 10:41 — "much cleaner golden"
- Golden refinements.
- Candidate baseline stabilization point.
- **Risk:** LOW-MEDIUM (YELLOW/GREEN boundary)

---

### RED — High-probability WireGuard regression period
### `3b50922` — 2026-04-22 17:35 — "nightmare inducing LLM..."
**Critical indicators:**
- `lib/topology/mkWireguardPeers.nix` uses placeholder keys:
  - `publicKey = "placeholder-${...}"`
- `machines/cortex-alpha/default.nix` imports `../../modules/enable-wg.nix` (client module) on router hub
- Topology host key/peer name divergence (`*-wg` aliases vs non-aliased peer names)
- Generator logic filtered null peers (silent loss of peers)

**Operational interpretation:** Tailscale can still come up independently while WireGuard peers fail due to invalid keys and/or malformed peer set.

- **Risk:** HIGH (RED)

---

### YELLOW — Partial repairs, still unsafe until key handling corrected
### `8a32e8f` — 2026-04-23 12:11 — "pure evil"
- Removes `enable-wg.nix` from hub (good correction)
- But placeholder key pattern still present in topology WG generator at this stage
- **Risk:** MEDIUM-HIGH (YELLOW)

---

### GREEN — WireGuard key handling repaired
### `2dfe25a` — 2026-04-24 16:52 — "further repair the llm nightmare"
- `mkWireguardPeers` changed to read actual public keys from:
  - `secrets/public_keys/wireguard/wg_${peerName}_pub`
- `core-router` updated to pass `self` for key path resolution
- **Risk:** LOW (GREEN)

### `0c25e48` — 2026-04-27 12:39 — "resolving hell is hard and costs tokens"
- Converts missing host/IP/key to explicit failure (`throw`) instead of silent drops
- Adds topology validation assertion in `core-router`
- **Risk:** LOW (GREEN)

---

## Golden Master Lineage Audit
`real-topology/golden/cortex-alpha.json` commit history:
1. `fa33e16` (2026-04-22 10:22)
2. `8dae2b9` (2026-04-22 10:41)
3. `15dbc58` (2026-04-24 12:53)

Critical-key comparison outcome:
- `8dae2b9` -> `15dbc58`: **no diff** on key router subsystems:
  - `networking.wireguard.interfaces`
  - `networking.tailscale.advertisedRoutes`
  - `services.dnsmasq.settings`
  - `networking.firewall.interfaces`
  - `networking.nftables.ruleset`

## Conclusion on golden period correctness
- Your golden lineage appears to remain tied to a valid operational period for core network behavior.
- The probable WireGuard break came from code path changes around `3b50922`, not from a corrupted golden lineage after `8dae2b9`.

---

## Recommended Canonical Baselines

### Deployment behavior anchor (pre-refactor certainty)
- **`9103ebf`**

### Topology/golden anchor (post-refactor stable reference)
- **`8dae2b9`** (preferred canonical baseline commit for 2026-04-22 golden period)

### Anti-baseline (do not use as safe deployment reference)
- **`3b50922`** and immediate descendants until WG key/file fixes land

---

## Immediate Operational Guidance
1. Keep current strict WG behavior (real key files + fail-fast on missing peers/keys).
2. Keep `enable-wg.nix` excluded from hub machines.
3. After live validation, update golden intentionally from the validated deployed state.
4. Preserve this timeline as incident memory for future refactors.
