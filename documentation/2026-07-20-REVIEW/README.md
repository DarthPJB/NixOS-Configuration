# Overlord-II Cleaning Review — Master Document

**Date:** 2026-07-20
**Worktree:** `overlord-II-cleaning-review` (branch `overlord-II-cleaning-review`)
**Base checkout:** `/tmp/nixos-overlord-II-cleaning-review` (mirrors `overlord-II` @ 6a96bb8)
**Skill:** `/review` (agentic parallel codebase review)
**Commander:** hy3-free (autonomous execution)

## Scope

A *very deep* review of the Bargman-Tech NixOS-Configuration fleet on the
`overlord-II` branch, targeting three explicit grounds:

1. **Complete inventory of all nginx vhosts managed fleetwide.**
2. **Suggested paths to clean up or remove** — especially dead documentation
   and dead snippets, but also unused/duplicated modules and WIP cruft.
3. **Obvious practical issues** with the codebase, Nix design, or intended
   design patterns.

## Reviewers (parallel, identical prompt)

- `tpol-minimax` — research prep & synthesis
- `tuvok-deepseek` — logical / adversarial analysis
- `hoshi-xai` — documentation & content focus
- `bellana-grok-code` — engineering deep dive
- `bellana-codex` — fast execution (nginx enumeration)

## Constraints (from /review skill)

- Agents are **forbidden from accessing any live system**.
- Agents are **forbidden from making any code changes**.
- Only passive inspection: `read`, `grep`, `ls`, and Nix evaluation
  (`nix eval --option builders ''`, `nix run .#dump-config`, golden checks)
  are permitted.
- All file operations use absolute paths.
- Each agent writes a verbose report to the designated file.

## Process

1. Folder + prompts created (this document).
2. Agents dispatched in parallel with identical prompt (`PROMPT.md`).
3. Commander synthesises into `SYNTHESIS.md` and presents summary to user.

## Ground Truth Notes (for reviewers)

- Two-layer architecture: **production** (`modules/core-router.nix`,
  `lib/topology/mk*.nix` transformers → generators) and **WIP** (`mk*Settings`/
  `gen*` pattern, `modules/core-router-topology.nix` not yet wired).
- Golden tests in `goldens/` are sacrosanct; restructuring must not change them.
- Nginx vhosts may be defined in: `topology/*.nix`, `lib/topology/mkNginx*`,
  `lib/topology/genNginx.nix`, `modules/`, `server_services/`, `services/`,
  `snippets/`, `machines/*`, and `webroot/`.
