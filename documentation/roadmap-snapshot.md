# Roadmap Snapshot — April 2026

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
