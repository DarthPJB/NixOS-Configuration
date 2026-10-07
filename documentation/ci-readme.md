# CI/CD Documentation for NixOS Configuration

This file documents the CI/CD pipeline for the NixOS configuration
repository. The implementation lives in `ci.nix` (repo root) and
`ci/generate-workflow.nix`, with workflow configuration generated from
Nix evaluation.

## Security Posture

**All builds execute on self-hosted runners within our own environment.**
GitHub-hosted runners are inherently insecure — they have no place in
professional netrunner infrastructure. Bargman-Tech production builds are
siloed in closed infrastructure; GitHub is used only for public-facing projects.

Third-party build caching and relay services (Cachix, DetSys
magic-nix-cache, etc.) remain **removed from CI**. No external build cache
is configured.

**In-House Binary Cache: OPERATIONAL.** We operate our own signed Nix binary
cache, dogfooding our infrastructure capabilities: `services/nix-cache-serve.nix`
runs signed `nix-serve` on remote-builder (port 5001), published over TLS via
nginx at `cache.johnbargman.net`, with the signing key managed by secrix
(`secrets/cache-priv-key`). Builds substitute from the in-house cache first
and only build locally on cache misses. Approved substituters are
`cache.johnbargman.net` and `cache.nixos.org` (fleet `trusted-substituters`)
plus, at the flake level, `cache.johnbargman.net` and
`install.determinate.systems` (Determinate Nix artifacts). Flake inputs are
fetched via FlakeHub. FlakeHub and install.determinate.systems are the only
approved third-party inputs.

**Correctness is non-negotiable.** If `nix flake check` takes four hours to
evaluate all machines, that is acceptable — provided it guarantees correctness.
Slow-and-correct obliterates fast-and-wrong.

## Overview

The CI/CD pipeline generates GitHub Actions workflow configuration directly
from Nix evaluation. This ensures CI configuration is always in sync with
actual build requirements.

## Files

- `ci.nix` (repo root) - Main CI module with job definitions; machine lists
  auto-derived from `nixosConfigurations`
- `ci/generate-workflow.nix` - Workflow generator (Nix → JSON → YAML via PyYAML)
- `documentation/ci-readme.md` - This file (documentation)

## Quick Start

```bash
# Generate CI workflow (outputs YAML to stdout)
nix run .#generate-ci-workflow --option builders '' > .github/workflows/ci.yml

# Validate workflow
nix run .#validate-ci-workflow --option builders ''

# View generated workflow
cat .github/workflows/ci.yml

# Commit to repository
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow"
```

## Usage

The primary command generates YAML directly to stdout for redirection:

```bash
nix run .#generate-ci-workflow --option builders '' > .github/workflows/ci.yml
```

This will output build warnings to stderr (normal for `nix run`) and the YAML workflow to stdout, which is redirected to the file.

## CI Jobs

Job definitions live in `ci.nix`. Machine matrices are auto-derived from the
flake's `nixosConfigurations` — there are no hardcoded machine lists.

### 1. Validation & Linting (validation)
- Runs on self-hosted runners for all pushes and PRs
- Code formatting check (`nix fmt -- --check .`)
- Flake validation (`nix flake check` — includes the deadnix check
  `checks.x86_64-linux.deadnix`)
- Evaluation profiling (diagnostic, continue-on-error)
- Dead code detection (`nix shell nixpkgs#deadnix -c deadnix .`,
  continue-on-error) — there is no `nix run .#deadnix` app

### 2. Security Scan (security)
- Runs on `ubuntu-latest` (scan-only job — all builds run on self-hosted runners)
- Gitleaks secret scanning (full git history, `fetch-depth: 0`)
- Plaintext-secrets grep over `*.nix` files (warn-only)
- Hardcoded-IP grep over `*.nix` files (excludes the VPN range and documentation)

### 3. Build x86_64 Configurations (build-x86)
- **Depends on**: validation, security
- Matrix over auto-derived x86_64 machines (self-hosted runners)
- 12h timeout (LINDA cold-cache builds take ~6h)

### 4. Build ARM (native aarch64) (build-arm-native)
- **Depends on**: validation, security
- Matrix over auto-derived ARM machines built natively on the aarch64 runner

### 5. Build ARM (cross-compiled from x86_64) (build-arm-cross)
- **Depends on**: validation, security
- Matrix over auto-derived ARM machines cross-compiled from the x86_64 runner

### 6. Deploy (deploy-prep)
- **Depends on**: validation, security, build-x86, build-arm-native, build-arm-cross
- Manual trigger only (`workflow_dispatch`; job name "Deploy - <machine>")
- Builds **only the selected machine** (not all machines)
- Action choices: build, test, deploy

## Machine Matrix

Machine matrices are auto-derived from the flake's `nixosConfigurations`;
`ci.nix` categorizes each machine by host/build platform (x86_64 native,
aarch64 native, ARM cross-compiled from x86_64). There are no hardcoded
machine lists in the CI configuration.

**18 active machines** (21 machine directories minus 3 dormant: alpha-two,
storage-array, display-0). Dormant machines are preserved in `flake.nix`
`dormantConfigurations` for golden tests but are not included in
`nixosConfigurations` to prevent accidental deployment — and therefore are
never built in CI. `ci.nix` `ciExclusions` additionally skips non-deployment
configs (the cluster-box passthrough and the bargman-greeter-vm test VM).
The full fleet list lives in `AGENTS.md`.

## Workflow Triggers

### Automatic Triggers
- Push to `main` branch
- Pull requests to `main` branch
- Changes to `**.nix` files
- Changes to `flake.lock`
- Changes to `.github/workflows/**` (push trigger only)

### Manual Triggers
- `workflow_dispatch` for deployment
- Machine selection
- Action selection (build/test/deploy)

## Deployment Process

### Prerequisites
1. GitHub repository with Actions enabled
2. **Self-hosted runner** registered and online (GitHub-hosted runners are not
   used for proprietary builds — see Security Posture)
3. Nix installed on runner with `nixos-rebuild` available
4. VPN access (WireGuard) for deployment
5. Secret decryption keys (via secrix)

### Deployment Steps
1. Go to GitHub Actions tab
2. Select "NixOS CI/CD" workflow
3. Click "Run workflow"
4. Select machine from dropdown
5. Select action (build/test/deploy)
6. Click "Run workflow"

### Deployment Safeguards
- Manual trigger required
- Environment protection rules
- VPN access required
- Secret decryption needed
- Audit trail maintained

## Customization

### Adding New Machines
1. Add machine to `flake.nix`
2. Machine lists in `ci.nix` are auto-derived — nothing to update there
3. Regenerate workflow: `nix run .#generate-ci-workflow --option builders ''`
4. Commit changes

### Modifying CI Jobs
1. Edit `ci.nix` module
2. Update job definitions
3. Regenerate workflow: `nix run .#generate-ci-workflow --option builders ''`
4. Test locally: `nix run .#validate-ci-workflow --option builders ''`
5. Commit changes

### Changing Triggers
1. Modify `on` section in `ci.nix`
2. Regenerate workflow
3. Test trigger conditions
4. Commit changes

## Monitoring

Build status is tracked on self-hosted runners. External monitoring (Slack,
email, status badges) is secondary to system correctness. Correctness metrics
are primary:

- Golden test pass/fail for hub machines
- Build completion (not build speed)
- Evaluation integrity (flake check passes fully)

## Troubleshooting

### Common Issues

#### Workflow Not Running
- Check GitHub Actions is enabled
- Verify file paths in triggers
- Check branch names match

#### Build Failures
- Run `nix flake check --option builders ''` locally
- Verify machine configuration
- Check for syntax errors
- Review build logs

#### Deployment Issues
- Verify VPN connectivity
- Check secret decryption
- Verify SSH access
- Check deploy user permissions

### Debugging Commands
```bash
# Check CI configuration
nix eval --json .#ci.ci.github-actions --option builders '' | jq .

# View machine lists (auto-derived from nixosConfigurations)
nix eval --json .#ci.ci.machines --option builders '' | jq .

# Regenerate the CI workflow golden (canonical)
nix eval --json .#ci.ci.github-actions --option builders '' | jq -S . > goldens/ci.json

# Check CI config against golden
nix run .#check-ci --option builders ''

# Test workflow generation
nix run .#generate-ci-workflow --option builders ''

# Validate workflow
nix run .#validate-ci-workflow --option builders ''

# Check flake evaluation
nix flake show --option builders ''
```

## Best Practices

### Regular Maintenance
- Review build metrics weekly
- Update workflow monthly
- Test deployment procedures quarterly
- Audit security scans

### Performance Optimization
- Monitor cache effectiveness
- Track build time trends
- Optimize resource usage
- Review parallel execution

### Security
- Regular secret rotation
- Access control reviews
- Security scan monitoring
- Incident response planning

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Nix Flakes Documentation](https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html)
- [NixOS Configuration](https://nixos.org/manual/nixos/)
- [Repository Documentation](./)