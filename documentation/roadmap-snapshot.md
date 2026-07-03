# Roadmap Snapshot — April 2026

> **⚠️ HISTORICAL SNAPSHOT — DO NOT RELY ON FOR CURRENT STATUS**
>
> Extracted from roadmap.html (April 15, 2026). This file is preserved for
> historical reference only. It predates the overlord branch cycle and the
> phased development model.
>
> **For current status, see `AGENTS.md`** (Phases A–C, active architecture,
> golden test discipline, deployment flow).
>
> Key divergences as of July 2026:
> - Phase A (Backup Capabilities) is complete — `lib/rclone-target.nix` extended
>   with `mode`, `calendar`, `bwlimit`, `preExec`; gaming-host-1 daily backup
>   running.
> - Phase B (Transformer Architecture) is in progress — WIP transformers
>   (`mkDnsSettings`, `mkFirewallSettings`, `mkNginxSettings`) and generators.
> - Phase C (Library Split: ketchup/secret-sauce/mayo) is planned.
> - Build array planning (Phase 0–5) has been scoped but deprioritized.
> - ARM CI is blocked pending arm-builder hardware restoration.
> - SSH multiplexing via topology is planned for overlord-II (see
>   `plans/ssh-multiplex-topology-2026-07-03.md`).

Extracted from roadmap.html (April 15, 2026). Historical snapshot of development goals, technical debt, and success metrics. For current phased development status, see `AGENTS.md`.

## Development Timeline

| Phase | Period | Status |
|-------|--------|--------|
| Foundation & Core Infrastructure | Q4 2025 | Completed |
| Machine Expansion & Service Integration | Q1 2026 | Completed |
| Security & Authentication | Q2 2026 | In Progress |
| Automation & Advanced Features | Q3 2026 | Planned |
| Optimization & Scaling | Q4 2026 | Planned |
| Enterprise Features | 2027 | Future |

## Goal Completion (as of April 2026)

| Area | Completion | Notes |
|------|------------|-------|
| Network Infrastructure | 75% | IPv6 incomplete, VPN operational |
| Security Enhancements | 60% | LDAP, GPG SSH pending |
| Monitoring & Observability | 80% | Prometheus/Grafana operational |
| Automation & Deployment | 70% | CI/CD in progress |

## Technical Debt Inventory

### High Priority
- Hardcoded IP addresses in configurations (15+)
- Incomplete IPv6 implementation
- Missing comprehensive testing
- Inconsistent naming conventions

### Medium Priority
- Commented-out legacy code (5+ blocks)
- TODO comments scattered in codebase (20+)
- Incomplete documentation (10+ items)
- Missing automation scripts

### Low Priority
- Code style inconsistencies
- Missing unit tests
- Outdated dependencies
- Performance optimizations

## Success Metrics

| Metric | Target |
|--------|--------|
| Uptime | > 99.9% |
| Deployment time | < 5 minutes |
| Build time | < 10 minutes |
| Recovery time | < 15 minutes |
| Security incidents | 0 |
| Declarative config | 100% |

## Backlog Items

- Multi-site deployment planning
- AI/ML integration research
- Advanced compliance features
- Enterprise feature development
- rEFInd bootloader investigation (alternative & porting)
