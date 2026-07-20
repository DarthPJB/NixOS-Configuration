# Unified Review Prompt — Overlord-II Cleaning Review

You are one of several parallel reviewers performing a **very deep** review of
the Bargman-Tech NixOS fleet configuration. You share this exact prompt with
every other reviewer. Your job is to investigate thoroughly and report
verbosely — NOT to change anything.

## Repository under review

**Absolute path:** `/tmp/nixos-overlord-II-cleaning-review`

This is a git worktree of the NixOS-Configuration repo on the `overlord-II`
branch. Treat it as the source of truth for the review. Do not look at other
checkouts unless cross-referencing.

## Hard constraints

1. **NO code changes.** Do not edit, write, or move any repository file except
   your own report file inside the review folder.
2. **NO live-system access.** Do not SSH, do not connect to any host, do not
   deploy. Passive inspection only.
3. **Tools allowed:** `read`, `grep`, `ls`/directory listing, `glob`, and Nix
   evaluation commands such as:
   - `nix eval --option builders '' .#...` (read-only attribute inspection)
   - `nix run .#dump-config -- <machine>` (inspect rendered config)
   - `nix run .#check-network -- <machine>` (golden diff, read-only)
   - `nix build --option builders '' --dry-run ...` (if informative)
   Use `--option builders ''` on ALL nix commands.
4. **Absolute paths only** in any file operations.
5. Write your final verbose report to:
   `/tmp/nixos-overlord-II-cleaning-review/documentation/2026-07-20-REVIEW/<YOUR-AGENT-NAME>-REVIEW-2026-07-20.md`

## What to investigate (three grounds)

### Ground 1 — Complete inventory of all nginx vhosts managed fleetwide
Enumerate EVERY nginx virtual host / server block / proxy definition managed
anywhere in the fleet. Search exhaustively across (but not limited to):
- `topology/*.nix` (per-machine and shared)
- `lib/topology/mkNginx*.nix`, `lib/topology/genNginx.nix`
- `modules/*.nix` (core-router, enable-wg-topology, etc.)
- `server_services/`, `services/`, `snippets/`
- `machines/*` (every machine's config)
- `webroot/`, `flake.nix` (service definitions)
- Any `services.nginx.virtualHosts` or raw `configFile`/extraConfig blocks.

For EACH vhost capture:
- The **domain / server_name** (or wildcard/none)
- The **listening port(s)** and whether TLS is used
- The **upstream / proxy target** (if a reverse proxy)
- **Where it is defined** (file + attribute path)
- **Which machine(s)** it is deployed to
- Whether it is **active in production** or only in WIP/legacy/dead code
- Any duplication (same vhost defined in multiple places)

If feasible, corroborate with `nix run .#dump-config -- <machine>` for a few
representative machines and note discrepancies between the declarative source
and the rendered config.

### Ground 2 — Suggested paths to clean up or remove
Identify **dead, duplicated, deprecated, or low-value** artifacts:
- **Dead documentation:** files in `documentation/` (and `docs/`, `README`s)
  that reference nonexistent files/attributes, describe abandoned plans (e.g.
  plans that were superseded), contain stale status, or are pure WIP scratch.
  Cross-reference claims against the actual tree. Note specific files and WHY
  they are dead.
- **Dead snippets:** entries in `snippets/` not referenced by any machine or
  module; deprecated subfolders (e.g. `snippets/grafana-deprecated`).
- **Unused/duplicated lib modules:** `lib/topology/*` files not imported by
  anything, or transformers that duplicate each other (production vs WIP).
- **WIP cruft:** WIP architecture files (`mk*Settings`, `gen*`,
  `core-router-topology.nix`, `enable-wg-topology.nix`) that are dead code
  because not wired into any machine, or that duplicate production behavior.
- **Orphaned secrets / public key files** referenced nowhere.
- **Build artifacts / caches / temp files** accidentally tracked.

For each item give: exact path, evidence it is dead/unused, and a
recommended action (delete / archive / consolidate).

### Ground 3 — Obvious practical issues with codebase, Nix design, or intended design patterns
Critique the actual implementation against the stated design philosophy in
`AGENTS.md` and `documentation/` (correctness over speed, closed-system builds,
golden tests as ground truth, simplicity over cleverness, phase discipline,
dual-layer transformers→generators). Look for:
- Duplication / drift between the **production** path and the **WIP** path;
  risk that the two diverge and golden tests silently cover only one.
- The serializer in `lib/serialize-config.nix` vs per-generator output shapes.
- Whether `enable-wg-topology.nix` (13 machines) and `core-router-topology.nix`
  (unwired) actually produce identical output to production — and the hazard if
  they don't.
- Formatter/config fragility (nixpkgs-fmt vs linter must match — documented
  risk).
- Secrets handling correctness (secrix references, WireGuard key paths).
- Any obvious Nix anti-patterns: `lib.getExe` violations, `writeShellScript`
  instead of `writeShellApplication`, hardcoded store paths, impurity, eval-time
  filesystem reads that break reproducibility.
- Scalability/maintainability smells as the fleet grows (21 machines already).
- Anything that would make a new engineer's life harder.

Be concrete: cite file paths and line references. Distinguish **definite bugs**
from **design risks** from **style nits**.

## Output format

Write a verbose Markdown report. Structure it with clear headings per ground.
Under each, use bullet lists and tables where helpful. Include:
- A **Summary** at the top (3–5 sentences).
- Ground 1: a table or list of all vhosts found.
- Ground 2: a prioritized list (High / Medium / Low) of cleanup candidates
  with paths + evidence + recommended action.
- Ground 3: prioritized findings with severity (Bug / Risk / Nit) + file:line
  evidence + recommended fix.
- A short **"Things I could not verify"** section noting limits of passive
  review.

Do not summarise other reviewers' work; produce YOUR independent findings.
