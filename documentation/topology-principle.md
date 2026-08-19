# Topology Generator Principle

**This document is the canonical source for the architecture principle.**

## The Principle

Topology generators are **pure JSON-to-attrset functions**. They:

- Read **only** JSON topology files (`topology/*.json`)
- Never read, access, or reference any user Nix files
- Never read NixOS config, module system state, or hostname
- Produce plain config attrsets (e.g., `{ networking.firewall = {...}; }`)
- Are merged with user config later by the NixOS module system

**The JSON is the source of truth. The generator is a pure transformation.**

## Architecture Flow

```
topology/<machine>.json
    ↓ (builtins.fromJSON)
gen*.nix  (pure function: JSON → attrset)
    ↓
{ networking.firewall = ...; services.nginx = ...; }
    ↓ (NixOS module merge)
final system configuration
    ↓
golden = ground truth
```

## Enforcement

- Generators must be pure functions: JSON in, attrset out
- No generator may read user Nix files or module state
- Violations are architectural errors and must be rejected
- See `topology-architecture.md` for the full data flow diagram
