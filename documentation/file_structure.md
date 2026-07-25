# File Structure

This document describes the directory layout of the NixOS-Configuration repository.


## Root Level
- `flake.nix` - Main flake definition with inputs, outputs, and system configurations
- `configuration.nix` - Legacy NixOS configuration (may be minimal or transitional)
- `AGENTS.md` - Instructions for AI agents working on this repository

## Core Configuration Directories
- `machines/` - Machine-specific NixOS configurations
  - One subdirectory per host (e.g., `cortex-alpha/`, `terminal-zero/`)
  - Each contains `default.nix` for primary config and `hardware-configuration.nix` for auto-generated hardware details
- `topology/` - Topology data (single source of truth)
  - `shared.nix` - Shared topology data (WireGuard IPs, LAN IPs, hub relationships)
  - `<machine>.nix` - Per-machine topology data (DNS, nginx, firewall, WireGuard, etc.)
  - `default.nix` - Entry point, imports shared + per-machine files
  - `external/` - Non-Nix-managed systems (APs, external PCs, WireGuard-only peers)
- `goldens/` - Golden test files (sacrosanct)
  - `<machine>.json` - Golden test references for each machine
- `lib/topology/` - Topology transformation functions
  - `mk*.nix` - Transformers (topology data → flat settings)
  - `gen*.nix` - Generators (settings → NixOS config)
  - `validate.nix` - Topology validation
  - `utils.nix` - Shared utilities
- `lib/serialize-config.nix` - The one config serializer (used by `dump-config` and `checks.network-config-*`)
- `lib/golden_coverage.nix` - Coverage audit (separate tool; checks if every machine has a golden)
- (Note: `lib/golden_generator.nix` is dead code from 2026-07-11 and should be deleted.)
- `modules/` - NixOS modules
  - `core-router.nix` - Hub machine module (production architecture)
  - `enable-wg-topology.nix` - WireGuard client module (deployed on 13 machines)
- `environments/` - Environment modules for software collections
  - Named by purpose (e.g., `code.nix` for development tools, `browsers.nix` for web apps)
  - Each file defines packages and services for a specific use case
- `users/` - User account configurations
  - One file per user (e.g., `darthpjb.nix`)
  - Defines user settings, packages, and permissions

## Supporting Directories
- `lib/` - Shared utility functions and libraries
  - Reusable Nix functions for common operations
- `services/` - Service-specific configurations
  - One file per service (e.g., `nextcloud.nix`, `prometheus.nix`)
  - Includes service options and setup logic
- `server_services/` - Server-specific service configurations
  - Game servers (Minecraft, Space Engineers, etc.)
- `modifier_imports/` - System-wide modifiers and features
  - Global settings like virtualization, builders, or energy saving
  - Applied across multiple machines as needed

## Assets and Secrets
- `secrets/` - Encrypted secrets managed by secrix
  - `private_keys/` - WireGuard private keys (encrypted)
  - `public_keys/` - Public cryptographic keys
    - `wireguard/` - WireGuard public keys (`wg_<hostname>_pub`)
    - `host_keys/` - SSH host keys
  - API tokens, passwords, other secrets
  - Never commit decrypted versions
- `dotfiles/` - User configuration files (dotfiles)
  - Symlinked via home-manager or manual setup
- `ascetics_bin/` - Binary assets and media files
  - Images, videos, scripts not part of Nix builds

## Development and Tools
- `documentation/` - Architecture docs, operational references, plans
- `scripts/` - Utility scripts (compare-configs.sh, etc.)
- `tests/` - NixOS tests and validation
- `llm/` - AI agent outputs and analysis
- `snippets/` - Reusable configuration snippets
- `kalymos/` - Project-specific subdirectories
- `locale/` - Localization and network settings

## Web and Services
- `webroot/` - Static web content
- `pkgs/` - Custom package derivations (minecraft-curseforge, etc.)