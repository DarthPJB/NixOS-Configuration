# LLM-CORE Integration Status

**Date:** 2026-07-13
**Updated:** 2026-07-25
**Branch:** overlord-II
**Status:** Phase 1 Complete — alpha-three deployed as testbed

---

## Summary

LLM-CORE has been successfully integrated into the NixOS fleet infrastructure. alpha-three is deployed as the first testbed with full fleet agents and MCP server support.

## What's Working

### On alpha-three (Deployed)
- **41 agents loaded** — full fleet (USS-Voyager, USS-Enterprise, USS-Defiant, USS-Discovery, USS-Valiant, USS-Protostar) plus built-in agents
- **8/8 MCP servers connected:**
  - filesystem, git, playwright, prometheus, sqlite, time — always working
  - github, gitlab — working via wrapper scripts + secrix token injection
- **opencode v1.15.10** and **crush v0.70.0** installed from `pkgs_llm`

### Fixes Applied to LLM-CORE (committed)

| Commit | Fix |
|--------|-----|
| `39cc94b` | Remove `{file:...}` syntax from opencode.json (unsupported by opencode) |
| `4245099` | Add full fleet user symlink support (not just voyagerOnly) |
| `bfebdcb` | Use actual user home directory via `config.users.users.${user}.home` |
| `f7533dc` | Wrapper scripts for github/gitlab MCP servers (runtime token injection) |

### Fixes Applied to NixOS-Configuration

| File | Fix |
|------|-----|
| `users/inspect.nix` | tmpfiles group: `inspect` → `users` (group didn't exist) |
| `users/deployment.nix` | tmpfiles group: `deploy` → `users` (group didn't exist) |
| `machines/alpha-three/default.nix` | Full opencode-fleet config with secrix permissions |
| `environments/code.nix` | opencode/crush sourced from `pkgs_llm` instead of `unstable` |
| `flake.nix` | LLM-CORE with nested follows for nixpkgs and nix-mcp-servers |

### Secrix Integration Pattern

The correct pattern for making secrets available to user-level processes (like opencode):

```nix
secrix.system.secrets.my-secret = {
  encrypted.file = ./secrets/my-secret;
  decrypted = {
    user = "John88";      # Must match the user running the process
    group = "users";       # Group membership
    mode = "0440";         # Owner + group readable
  };
};
```

Also adjust the secrets directory if needed:
```nix
secrix.system.secretsDir = {
  permissions = "0555";    # Traversable
  group = "users";
};
```

## Known Issues / Future Work

### ~~CRITICAL: Provider Specification (Next Version)~~ — RESOLVED

Provider specification has been implemented and confirmed working.
The `opencode-fleet` module now supports per-deployment provider configuration.

### ~~LINDA Deployment (Pending Authorization)~~ — RESOLVED

LINDA has been deployed with `opencode-fleet` and confirmed working.

### terminal-zero

No LLM-CORE integration planned — minimal terminal machine.

## Architecture

```
LLM-CORE (gitlab.com/mecha-team-zero/llm-core)
├── nixosModules.opencode-fleet
│   ├── Deploys agent fleet to /etc/opencode/agents
│   ├── Generates opencode.json with MCP server config
│   ├── Wrapper scripts for token-based MCP servers
│   └── tmpfiles rules for user-level agent access
├── packages (fleet generators, validation scripts)
└── inputs
    ├── nixpkgs (follows nixpkgs_llm)
    └── nix-mcp-servers (follows nixpkgs_llm)
```

## References

- LLM-CORE source: `gitlab.com/mecha-team-zero/llm-core`
- Secrix documentation: `/speed-storage/opencode/llm/shared/secrix_documentation.md`
- Opencode paths: `/speed-storage/opencode/llm/shared/opencode_paths.md`
- Agent loading: `/speed-storage/opencode/llm/shared/opencode_cli_agent_loading_confirmed_20260109.md`
