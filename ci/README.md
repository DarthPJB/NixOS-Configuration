# CI/CD Implementation for NixOS Configuration

This directory contains the CI/CD implementation for the NixOS configuration repository, with configuration generated from Nix evaluation.

## Overview

The CI/CD pipeline is unique because it generates GitHub Actions workflow configuration directly from Nix evaluation. This ensures that CI configuration is always in sync with actual build requirements.

## Key Features

- **Configuration as Code**: CI pipeline defined in Nix, version controlled
- **Reproducibility**: Same Nix evaluation produces same CI configuration
- **Consistency**: CI tests exactly what you build locally
- **Automation**: Workflow generation from machine definitions
- **Validation**: CI configuration can be tested before deployment

## Files

- `ci.nix` - Main CI module with job definitions
- `generate-workflow.nix` - GitHub Actions workflow generator
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
- Builds 12 x86_64 configurations in parallel
- Machines: terminal-zero, terminal-nx-01, cortex-alpha, local-nas, alpha-one, alpha-two, alpha-three, LINDA, gaming-host-1, remote-worker, storage-array, remote-builder
- Uploads build artifacts

### 3. Build ARM Job
- Builds 4 ARM configurations
- Machines: display-0, display-1, display-2, print-controller
- Generates SD card images for Raspberry Pi

### 4. Security Job
- Secret detection in Nix files
- Configuration validation
- Security best practices check

### 5. Deploy Job
- Manual trigger only (workflow_dispatch)
- Requires machine selection and action choice
- Deployment safeguards in place

## Machine Matrix

### x86_64 Machines (12)
- terminal-zero
- terminal-nx-01
- cortex-alpha
- local-nas
- alpha-one
- alpha-two
- alpha-three
- LINDA
- gaming-host-1
- remote-worker
- storage-array
- remote-builder

### ARM Machines (4)
- display-0
- display-1
- display-2
- print-controller

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
2. GitHub runner connected to account
3. Nix installed on runner
4. VPN access for deployment
5. Secret decryption keys

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

### Build Status
- GitHub Actions dashboard
- Build status badges
- Email notifications
- Slack integration (optional)

### Performance Metrics
- Build success rate
- Average build time
- Resource utilization
- Cache hit rate
- Failure patterns

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