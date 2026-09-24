# Monitoring Automation

**Scope:** How Grafana dashboards and the Prometheus monitoring inventory are
generated from topology + evaluated config, and what remains to automate.
**Status:** Phase 1 complete. Phase 2 is future work (see below).

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
- `lib/topology/dashboard_templates/` — dashboard templates.
- `services/graphana_dashboards/` — remaining hand-authored domain dashboards
  (AI, ZFS, storage, disk health, deployment, remote-builder).
- `services/prometheus.nix` — wires the inventory and provisions generated
  dashboards from the Nix store.

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

Auto-generate the monitoring inventory and Grafana dashboards.

- Inventory from config introspection + topology IPs + externals + job mapping,
  unioned with the blessed baseline, stable ordering.
- Generated dashboards provisioned from the Nix store via a dedicated Grafana
  file provider; static domain dashboards unchanged.
- **Golden impact: none.** Grafana is not serialized in `lib/serialize-config.nix`,
  so the inventory and dashboards can shift freely.

Verified: adding a machine with exporters enabled (e.g. `pillar-of-autum`) now
appears in generated dashboards automatically — no dashboard edits required.

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
