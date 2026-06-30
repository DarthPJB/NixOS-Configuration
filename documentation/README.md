# NixOS Configuration Documentation

This directory contains documentation for the NixOS Configuration repository.

## Documentation Structure

### Reference Documentation
- **[code_structure.md](code_structure.md)** - Code organization and patterns
- **[file_structure.md](file_structure.md)** - Directory layout and file organization

### Security & Operations
- **[security-reference.md](security-reference.md)** - User accounts, security layers, incident response
- **[operations-runbooks.md](operations-runbooks.md)** - Maintenance schedules, deployment runbooks
- **[secrix-workflow.md](secrix-workflow.md)** - Secrix encryption workflow

### Development
- **[development-guide.md](development-guide.md)** - Prohibited practices, troubleshooting procedures
- **[core-router-usage.md](core-router-usage.md)** - Core router module usage

### Topology & Networking
- **[topology-schema.md](topology-schema.md)** - Topology data schema
- **[topology-migration-guide.md](topology-migration-guide.md)** - Migration guide for topology changes
- **[topology-generator-issues.md](topology-generator-issues.md)** - Known issues (TG-003, TG-004)
- **[network-topology-golden.md](network-topology-golden.md)** - Golden test documentation
- **[tailscale-subnet-routers.md](tailscale-subnet-routers.md)** - Tailscale configuration
- **[dual-tailscale-plan.md](dual-tailscale-plan.md)** - Dual Tailscale plan

### Architecture & Planning
- **[backup-capacity-report.md](backup-capacity-report.md)** - Backup capacity report
- **[roadmap-snapshot.md](roadmap-snapshot.md)** - Historical snapshot of goals, debt, metrics (April 2026)
- **[tracking-research-decisions.md](tracking-research-decisions.md)** - Research decision tracking

### Specialized Guides
- **[arm-build-limitations.md](arm-build-limitations.md)** - ARM build limitations
- **[build-monitoring-pattern.md](build-monitoring-pattern.md)** - Build monitoring pattern
- **[denton-glasses-linda.md](denton-glasses-linda.md)** - Denton glasses on LINDA
- **[i3-balances.md](i3-balances.md)** - i3 window manager configuration
- **[hetzner-nixos-recovery-reference.md](hetzner-nixos-recovery-reference.md)** - Hetzner recovery reference
- **[nixos-rebuild-ng-deployment-analysis.md](nixos-rebuild-ng-deployment-analysis.md)** - Deployment analysis
- **[minecraft-fod-pattern.md](minecraft-fod-pattern.md)** - Minecraft FOD pattern
- **[minecraft-live-diagnostics.md](minecraft-live-diagnostics.md)** - Minecraft live diagnostics

### Incident Reports (`incidents/`)
- **[2026-06-28-voxtype-gpu-primaryIndex.md](incidents/2026-06-28-voxtype-gpu-primaryIndex.md)** - Voxtype GPU incident

### Plans (`plans/`)
- **[topology-rectification-2026-06-23.md](plans/topology-rectification-2026-06-23.md)** - Topology rectification plan
- **[declarative-dns-management.md](plans/declarative-dns-management.md)** - DNS management plan
- **[ci-ssh-injection-2026-06-26.md](plans/ci-ssh-injection-2026-06-26.md)** - CI SSH injection plan
- **[flake-input-consolidation.md](plans/flake-input-consolidation.md)** - Flake input consolidation plan

### Research (`research/`)
- **[gpu-primary-selection-nixos.md](research/gpu-primary-selection-nixos.md)** - GPU primary selection research

### Logs (`logs/`)
- **[investigation-item-clear-2026-06-16.md](logs/investigation-item-clear-2026-06-16.md)** - Investigation log

### Backup Survey Data (`backup-survey/`)
Raw survey outputs (lsblk, zpool, df, nix-store) per machine. Used by `backup-capacity-report.md`.
