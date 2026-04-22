## Architecture

### Topology-Driven Router Configuration

The topology-driven architecture follows a pattern: topology data → transformation functions → core-router module.

New files created:
- `real-topology/` - topology data
- `lib/topology/` - transformation functions
- `modules/core-router.nix` - core router module
- `systems/cortex-alpha.nix` - example machine

For router machines, use `systems/<hostname>.nix` with the core-router module for topology-driven network configuration:
```nix
# systems/<hostname>.nix
{ ... }:
{
  imports = [
    ../machines/<hostname>
    ../modules/core-router.nix
  ];
}
```
See `documentation/core-router-usage.md` for details.

## Common Tasks
- Migrate a machine to topology-driven configuration

## Repository Structure
New directories:
- `real-topology/` - topology data
- `lib/topology/` - transformation functions

## Deployment Flow