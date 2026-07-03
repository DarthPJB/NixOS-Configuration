# Flake Input Consolidation Plan

**Created**: 2026-06-28  
**Status**: READY FOR APPROVAL  
**Priority**: Immediate — Zero codebase impact  
**Execution**: Requires sudo via SSH to `10.88.127.88:1108` (deploy user)

## Objective

Consolidate all NixOS-Configuration flake inputs into `/speed-storage/bargman-tech/` to improve:
- Agentic workflow navigation
- Development velocity with local path inputs
- Single source of truth for all Bargman-Tech repos

## Approved Structure

```
/speed-storage/bargman-tech/
├── bargman-assets/              # GitLab: mecha-team-zero/bargman-assets
├── carmelsite/                  # GitLab: mecha-team-zero/carmelsite
├── denton-glasses/              # GitLab: mecha-team-zero/denton-glasses
├── macha-orchestration/         # GitLab: mecha-team-zero/macha-orchestration
├── ikbaeb-th/                   # GitHub: DarthPJB/IKBAEB-th
├── nixinate/                    # GitHub: Bargman-Tech/nixinate
├── parsec-gaming-nix/           # GitHub: DarthPJB/parsec-gaming-nix
├── ratty/                       # GitHub: DarthPJB/ratty
├── nixpkgs_stable/              # nixpkgs stable release branch
├── nixpkgs_unstable/            # nixpkgs-unstable branch
└── nixpkgs_llm/                 # nixpkgs-unstable branch (for LLM packages)

/home/pokej/bargman-tech -> /speed-storage/bargman-tech  # Symlink
```

## Migration Map

| Source | Destination | Action |
|--------|-------------|--------|
| `/speed-storage/repo/DarthPJB/nixinate` | `/speed-storage/bargman-tech/nixinate` | `mv` |
| `/speed-storage/repo/DarthPJB/ratty` | `/speed-storage/bargman-tech/ratty` | `mv` |
| `/speed-storage/repo/DarthPJB/ikbaeb-th-flake` | `/speed-storage/bargman-tech/ikbaeb-th` | `mv` (rename) |
| `/speed-storage/repo/DarthPJB/parsec-gaming-nix` | `/speed-storage/bargman-tech/parsec-gaming-nix` | `mv` |
| `/speed-storage/repo/DarthPJB/carmel_newsite` | `/speed-storage/bargman-tech/carmelsite` | `mv` (rename) |
| `/speed-storage/repo/DarthPJB/bargman-assets` | `/speed-storage/bargman-tech/bargman-assets` | `mv` |
| `/speed-storage/LLM-END/denton-glasses` | `/speed-storage/bargman-tech/denton-glasses` | `mv` |
| `/speed-storage/LLM-END/orhestratior-prime` | `/speed-storage/bargman-tech/macha-orchestration` | `mv` (rename) |
| `/speed-storage/LLM-JAIL/nixpkgs_fresh` | `/speed-storage/bargman-tech/nixpkgs_stable` | `cp` + checkout stable |
| `/speed-storage/LLM-JAIL/nixpkgs_fresh` | `/speed-storage/bargman-tech/nixpkgs_unstable` | `cp` + checkout nixpkgs-unstable |
| `/speed-storage/LLM-JAIL/nixpkgs_fresh` | `/speed-storage/bargman-tech/nixpkgs_llm` | `cp` + checkout nixpkgs-unstable |

## Nixpkgs Version Checkout

Current flake inputs:
- `nixpkgs_stable` = `https://flakehub.com/f/NixOS/nixpkgs/0` (FlakeHub stable)
- `nixpkgs_unstable` = `https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0` (Determinate weekly)
- `nixpkgs_llm` = `github:NixOS/nixpkgs/nixpkgs-unstable` (GitHub nixpkgs-unstable)

**Action:** Each nixpkgs copy should check out the branch matching its remote source:
- `nixpkgs_stable` → `release-25.11` or latest stable branch
- `nixpkgs_unstable` → `nixpkgs-unstable` branch
- `nixpkgs_llm` → `nixpkgs-unstable` branch

## Execution Steps

### Phase 1: Create Directory & Move Repos (Requires sudo)
```bash
# Create target directory
sudo mkdir -p /speed-storage/bargman-tech
sudo chown John88:users /speed-storage/bargman-tech

# Move repos (in situ - git repos, no codebase impact)
sudo mv /speed-storage/repo/DarthPJB/nixinate /speed-storage/bargman-tech/
sudo mv /speed-storage/repo/DarthPJB/ratty /speed-storage/bargman-tech/
sudo mv /speed-storage/repo/DarthPJB/ikbaeb-th-flake /speed-storage/bargman-tech/ikbaeb-th
sudo mv /speed-storage/repo/DarthPJB/parsec-gaming-nix /speed-storage/bargman-tech/
sudo mv /speed-storage/repo/DarthPJB/carmel_newsite /speed-storage/bargman-tech/carmelsite
sudo mv /speed-storage/repo/DarthPJB/bargman-assets /speed-storage/bargman-tech/
sudo mv /speed-storage/LLM-END/denton-glasses /speed-storage/bargman-tech/
sudo mv /speed-storage/LLM-END/orhestratior-prime /speed-storage/bargman-tech/macha-orchestration
```

### Phase 2: Set Up Nixpkgs Variants (Requires sudo)
```bash
# Copy nixpkgs_fresh as base
sudo cp -r /speed-storage/LLM-JAIL/nixpkgs_fresh /speed-storage/bargman-tech/nixpkgs_stable
sudo cp -r /speed-storage/LLM-JAIL/nixpkgs_fresh /speed-storage/bargman-tech/nixpkgs_unstable
sudo cp -r /speed-storage/LLM-JAIL/nixpkgs_fresh /speed-storage/bargman-tech/nixpkgs_llm

# Check out appropriate branches
cd /speed-storage/bargman-tech/nixpkgs_stable && sudo git checkout release-25.11
cd /speed-storage/bargman-tech/nixpkgs_unstable && sudo git checkout nixpkgs-unstable
cd /speed-storage/bargman-tech/nixpkgs_llm && sudo git checkout nixpkgs-unstable

# Fix ownership
sudo chown -R John88:users /speed-storage/bargman-tech/
```

### Phase 3: Create Symlink (Requires sudo)
```bash
sudo ln -s /speed-storage/bargman-tech /home/pokej/bargman-tech
sudo chown -h pokej:users /home/pokej/bargman-tech
```

### Phase 4: Update flake.nix (No sudo needed)
```nix
# Change inputs from remote URLs to local paths
inputs = {
  nixinate = { url = "path:/speed-storage/bargman-tech/nixinate"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
  ratty = { url = "path:/speed-storage/bargman-tech/ratty/fix/nix-module-improvements"; };
  ikbaeb-th = { url = "path:/speed-storage/bargman-tech/ikbaeb-th"; };
  parsecgaming = { url = "path:/speed-storage/bargman-tech/parsec-gaming-nix"; };
  carmelsite = { url = "path:/speed-storage/bargman-tech/carmelsite"; };
  bargman-assets = { url = "path:/speed-storage/bargman-tech/bargman-assets"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
  denton-glasses = { url = "path:/speed-storage/bargman-tech/denton-glasses"; };
  hype-train-outlaw = { url = "path:/speed-storage/bargman-tech/macha-orchestration"; };
  nixpkgs_stable = { url = "path:/speed-storage/bargman-tech/nixpkgs_stable"; };
  nixpkgs_unstable = { url = "path:/speed-storage/bargman-tech/nixpkgs_unstable"; };
  nixpkgs_llm = { url = "path:/speed-storage/bargman-tech/nixpkgs_llm"; };
  # ... other remote inputs unchanged
};
```

### Phase 5: Validation (No sudo needed)
```bash
# Test flake resolution
nix flake lock --update-input nixinate
nix flake check

# Test golden tests
nix run .#check-network -- cortex-alpha
```

## Zero Codebase Impact

- All repos are git repositories — `mv` preserves git history
- No files within NixOS-Configuration are modified until Phase 4
- `flake.nix` update is the only code change required
- `flake.lock` will update automatically on next `nix flake lock`

## Authorization Required

- [ ] User authorizes SSH to `10.88.127.88:1108` as `deploy`
- [ ] User confirms plan is ready for execution

---

**Awaiting authorization to proceed.**
