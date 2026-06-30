# CI/CD Implementation for NixOS Configuration

This directory contains the CI/CD implementation for the NixOS configuration
repository, with configuration generated from Nix evaluation.

## Security Posture

**All builds execute on self-hosted runners within our own environment.**
GitHub-hosted runners are inherently insecure — they have no place in
professional netrunner infrastructure. Bargman-Tech production builds are
siloed in closed infrastructure; GitHub is used only for public-facing projects.

Third-party build caching or relay services (e.g., DetSys "magic nix cache")
that have access to source code or build artifacts are not acceptable without
explicit, conscious authorization. Builds must complete from source within our
controlled environment unless a specific exception is granted.

**Correctness is non-negotiable.** If `nix flake check` takes four hours to
evaluate all machines, that is acceptable — provided it guarantees correctness.
Slow-and-correct obliterates fast-and-wrong.

## Overview

The CI/CD pipeline generates GitHub Actions workflow configuration directly
from Nix evaluation. This ensures CI configuration is always in sync with
actual build requirements.

## Files

- `ci.nix` - Main CI module with job definitions and machine registry
- `generate-workflow.nix` - Workflow generator (Nix → JSON → YAML via PyYAML)
- `CORRECTION_PLAN.md` - Historical audit of CI issues (some items are
  intentionally deferred — see Security Posture above)
- `README.md` - This file

## Quick Start

```bash
# Generate CI workflow (outputs YAML to stdout)
nix run .#generate-ci-workflow > .github/workflows/ci.yml

# Validate workflow
nix run .#validate-ci-workflow

# View generated workflow
cat .github/workflows/ci.yml

# Commit to repository
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow"
```

## Usage

The primary command generates YAML directly to stdout for redirection:

```bash
nix run .#generate-ci-workflow > .github/workflows/ci.yml
```

This will output build warnings to stderr (normal for `nix run`) and the YAML workflow to stdout, which is redirected to the file.

## CI Jobs

### 1. Validation Job
- Runs on all pushes and PRs
- Code formatting check (`nix fmt -- --check .`)
- Flake validation (`nix flake check`)
- Dead code detection (`nix run .#deadnix`)

### 2. Build x86 Job
- **Depends on**: validation, security
- Builds 12 x86_64 configurations in parallel
- Machines: terminal-zero, terminal-nx-01, cortex-alpha, local-nas, alpha-one, alpha-two, alpha-three, LINDA, gaming-host-1, remote-worker, storage-array, remote-builder
- Artifact upload with 7-day retention
- Uploads build artifacts

### 3. Build ARM Job
- **Depends on**: validation, security
- Builds 5 ARM configurations
- Machines: display-0, display-1, display-2, print-controller, **beta-one**
- Generates SD card images for Raspberry Pi
- Artifact upload with 7-day retention

### 4. Security Job
- **Gitleaks integration** for comprehensive secret scanning
- Enhanced pattern matching with exclusions
- IP address validation (VPN range only)
- Configuration validation
- Security best practices check
- Full git history scanning (`fetch-depth: 0`)

### 5. Deploy Job
- **Depends on**: validation, security, build-x86, build-arm
- Manual trigger only (workflow_dispatch)
- Builds **only the selected machine** (not all machines)
- Action choices: build, test, deploy
- 30-day log retention
- Deployment safeguards in place

## Machine Matrix

### x86_64 Machines (12)
- terminal-zero, terminal-nx-01, cortex-alpha, local-nas
- alpha-one, alpha-two (dormant), alpha-three, LINDA
- gaming-host-1, remote-worker, storage-array (dormant), remote-builder

### ARM Machines (5)
- display-0, display-1, display-2
- print-controller (Raspberry Pi 3)
- **beta-one** (armv7l-linux)

**Total: 17 machines** (15 active + 2 dormant).
Dormant machines are preserved in `dormantConfigurations` for golden tests
but are not included in `nixosConfigurations` to prevent accidental deployment.

## Workflow Triggers

### Automatic Triggers
- Push to `main` or `jb/ai/overlord-8` branches
- Pull requests to `main` branch
- Changes to `**.nix` files
- Changes to `flake.lock`
- Changes to `.github/workflows/**`

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
2. Update machine lists in `ci.nix`
3. Regenerate workflow: `nix run .#generate-ci-workflow`
4. Commit changes

### Modifying CI Jobs
1. Edit `ci.nix` module
2. Update job definitions
3. Regenerate workflow: `nix run .#generate-ci-workflow`
4. Test locally: `nix run .#validate-ci-workflow`
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
- Run `nix flake check` locally
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
nix eval --json .#ci.github-actions | jq .

# View machine lists
nix eval --json .#ci-info

# Test workflow generation
nix run .#generate-ci-workflow

# Validate workflow
nix run .#validate-ci-workflow

# Check flake evaluation
nix flake show
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
- [Repository Documentation](../documentation/)