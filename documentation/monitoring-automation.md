# Monitoring Automation

**Scope:** How Grafana dashboards and the Prometheus monitoring inventory are
generated from topology + evaluated config, and what remains to automate.
**Status:** Phase 1 complete, deployed and verified on `local-nas`. Phase 2 is
future work (see below).
**Last verified:** 2026-09-25 — 9 generated dashboards provisioned from the
Nix store, all `provisioned`, legacy DB state clean.

---

## Dashboard inventory

All 9 dashboards are generated from `lib/topology/dashboard_templates/` via
`lib/topology/genDashboard.nix` + `lib/monitoring/inventory.nix`. There is no
static dashboard JSON.

| UID | Title | Covers | Host generation |
|---|---|---|---|
| `fleet-cpu-disk` | Fleet Admin (heavy) | CPU, mem, disk, network, energy, GPU, services + "Node Detail" (swap/IOPS/latency/PSI/procs, folded from remote-builder) | rename transforms, node job union |
| `fleet-cpu-disk-light` | Fleet Overview (display) | CPU, mem, disk, filesystem, ZFS | rename transforms, node job union |
| `fleet-network` | Fleet Network | interface bandwidth, status, errors, drops | rename transforms |
| `cpu-frequency-per-machine` | CPU Frequency (per machine) | per-host core-frequency heatmap | full per-host fan-out + layout |
| `service-health` | Service Health | systemd unit failures, key services | templated |
| `storage-health` | Storage Health | SMART, temp, sectors, lifetime, disk I/O/latency/queue, filesystem, ZFS | rename transforms |
| `ai-systems` | AI Systems | GPU util, VRAM, temp, power, clocks | GPU job union + renames (was hardcoded IPs) |
| `ai-inference` | AI Inference | vLLM/LiteLLM request rate, latency, KV cache, errors | model-scoped (no host gen) |
| `fleet-deployment` | Fleet Deployment Status | NixOS generation, version, uptime, kernel | rename transforms |

---

## Background

Grafana dashboards were previously hand-authored JSON (`services/graphana_dashboards/`)
with host membership baked into job regexes and `renameByRegex` transforms. Every
time a machine was added or removed, those transforms and job unions went stale.

Dashboards are now **generated** from a monitoring inventory. The inventory is
built by unioning a blessed baseline with config-derived discovery, so adding or
removing a machine updates every generated dashboard at once.

### Architecture

```
topology/<machine>.json ──→ mkRegistry ──→ IPs
                                          │
self.nixosConfigurations ──→ config introspection ──→ enabled exporters + ports
                                          │
                       explicit externals ┘  (hyperhyper, cluster-box specials)
                                          ↓
              lib/monitoring/inventory.nix  (union + job mapping + stable order)
                                          ↓
              lib/topology/genDashboard.nix  +  dashboard_templates/
                                          ↓
                     generated Grafana dashboards (store)
                                          ↓
              services/prometheus.nix  →  Grafana "topology" file provider
```

**Files:**
- `lib/monitoring/inventory.nix` — the monitoring inventory (union of baseline
  and config-derived discovery). Reads evaluated NixOS config via `self`.
  Deliberately **not** in `lib/topology/` — the topology toolset must stay pure
  (JSON in, attrset out). See `documentation/topology-principle.md`.
- `lib/topology/genDashboard.nix` — pure inventory → dashboard generator.
- `lib/topology/dashboard_templates/` — dashboard templates (fleet, network,
  per-machine CPU fan-out, service health, storage, AI, deployment).
- `services/prometheus.nix` — wires the inventory and provisions generated
  dashboards from the Nix store. All dashboards are generated — there is no
  static dashboard JSON.

### Inventory construction

`lib/monitoring/inventory.nix` builds each exporter's host list as a **union**
with **stable ordering**:

- **baseline** — the blessed current scrape set (membership + order), including
  stale targets. The set only ever grows.
- **discovered** — config-derived: every prometheus exporter actually enabled on
  a machine (`services.prometheus.exporters.<name>.enable`), read from
  `self.nixosConfigurations` via `tryEval` (so removed options — `minio`,
  `rspamd`, `tor` — are skipped safely). Newly-enabled hosts are appended after
  the baseline.

**Job mapping** files each exporter under the job that actually consumes it
(`cluster-box` node → `malayalam-node`, `cluster-box` nvidia → `malayalam-nvidia`,
`hyperhyper` → `hyperhyper-*`). This keeps dashboard job unions
(`nodeJobs = ["node" "hyperhyper-node" "malayalam-node"]`) correct as hosts change.

**Externals** (no NixOS config in this flake): `hyperhyper` on Tailscale
(`100.107.101.14`). Dormant machines (`self.dormantConfigurations`) are excluded
— they are not deployed and not scraped.

---

## Phase 1 — COMPLETE (golden-safe)

Auto-generate the monitoring inventory and all Grafana dashboards.

- Inventory from config introspection + topology IPs + externals + job mapping,
  unioned with the blessed baseline, stable ordering.
- **All dashboards are generated** and provisioned from the Nix store via a
  single Grafana file provider. The legacy hand-authored static dashboards were
  folded into generative templates (`storage-health` consolidating
  ZFS/storage/disk-health, `ai-systems`, `ai-inference`, `fleet-deployment`) or
  folded into existing ones (`remote-builder`'s unique panels → `fleet-cpu-disk`
  "Node Detail"). No static dashboard JSON remains.
- **Golden impact: none.** Grafana is not serialized in `lib/serialize-config.nix`,
  so the inventory and dashboards can shift freely.

Verified: adding a machine with exporters enabled (e.g. `pillar-of-autum`) now
appears in generated dashboards automatically — no dashboard edits required.

---

## Deployment & verification

Deployed to `local-nas` and verified over SSH (2026-09-25):

- Grafana healthy (`/api/health` = 200); single `topology` file provider → the
  generated store dir. No `static` provider.
- Unified storage (`resource` table) holds exactly the 9 expected dashboards,
  every one marked **`provisioned`** (immutable Nix config).
- Legacy DB state clean: `dashboard` table = 0 rows, `dashboard_provisioning`
  = 0 links. (A prior deploy left 9 stale rows from an old provisioning path;
  these were removed imperatively so the deploy is declarative.)
- Folds/deletions landed: `remote-builder` → `fleet-cpu-disk` "Node Detail";
  `ai-systems` has zero hardcoded `instance=~` selectors; legacy dashboards
  (`failstate`, `linda-system`, `network-wireguard`, `remote-builder`,
  `storage-io`, `zfs-health`, `disk-health`) absent.

**Verification commands** (on `local-nas`):
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://10.88.127.3:3101/api/health
ls /nix/store/*-grafana-dashboards-generated/
sqlite3 /var/lib/grafana/data/grafana.db \
  "SELECT name FROM resource WHERE \"group\"='dashboard.grafana.app' ORDER BY name"
sqlite3 /var/lib/grafana/data/grafana.db \
  "SELECT COUNT(*) FROM dashboard"   # expect 0
```

---

## Phase 2 — FUTURE WORK: generate scrape configs (additive-only)

Replace the hand-maintained `scrapeConfigs` blocks in `services/prometheus.nix`
with generated scrape configs derived from the same inventory.

**Constraint (hard):** no scraper change may cause a golden regression unless it
is **adding** scrapers. Scrape generation must therefore be **monotonic
(superset-only)**: existing jobs, targets, ordering, and labels are frozen.

### Why this is non-trivial

Config introspection alone is **not** safe to drive scrapers. It would
**remove** existing targets that are scraped today but whose exporters are
disabled:

| Target | In current scrape? | Exporter actually enabled? |
|---|---|---|
| `display-1` smartctl (`10.88.127.41:3107`) | yes | no (`lib.mkForce false`) |
| `display-2` smartctl (`10.88.127.42:3107`) | yes | no (`lib.mkForce false`) |
| `remote-worker` smartctl (`10.88.127.50:3107`) | yes | no (`lib.mkForce false`) |
| `print-controller` smartctl (`10.88.127.30:3107`) | yes | no (`lib.mkForce false`) |
| `pillar-of-autum` node + smartctl | no | yes (addition) |

Generating purely from config would delete the 4 stale smartctl targets (a
golden regression) and add `pillar-of-autum` (permitted). The inventory's
**baseline** already pins the stale targets and preserves ordering — Phase 2
must generate from that inventory, **not** from raw config introspection.

### Required design

1. Generate `scrapeConfigs` from `lib/monitoring/inventory.nix` (the union),
   **not** from raw config introspection.
2. Preserve existing job order, target order within each job, and all labels.
   New targets are **appended** only.
3. **Guardrail:** assert generated ⊇ current before shipping. Any removal,
   reorder, or label change must abort.
4. Expected golden diff for `local-nas`: **additions only**
   (`pillar-of-autum` into `node` and `smartctl`). Regenerating the golden is
   permitted because the change is *adding* scrapers.
5. The 4 stale smartctl targets stay pinned as legacy until explicitly
   authorized for removal (a separate, deliberate decision — not part of this).

### Out of scope

- Removing or "tidying" stale scraper targets (would be a golden regression).
- Changing scrape intervals, labels, or job names of existing scrapers.
