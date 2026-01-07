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
- `modifier_imports/` - System-wide modifiers and features
  - Global settings like virtualization, builders, or energy saving
  - Applied across multiple machines as needed

## Assets and Secrets
- `secrets/` - Encrypted secrets managed by secrix
  - WireGuard keys, API tokens, passwords
  - Never commit decrypted versions
- `public_key/` - Public cryptographic keys
- `dotfiles/` - User configuration files (dotfiles)
  - Symlinked via home-manager or manual setup
- `ascetics_bin/` - Binary assets and media files
  - Images, videos, scripts not part of Nix builds

## Development and Tools
- `llm/` - AI agent outputs and analysis
  - Briefings, task analyses, and shared summaries
- `snippets/` - Reusable configuration snippets
  - Quick templates for common setups
- `kalymos/` - Project-specific subdirectories
  - Custom hardware projects or specialized configs
- `locale/` - Localization and network settings
  - Time zones, locales, WiFi configurations

## Web and Services
- `webroot/` - Static web content
- `server_services/` - Server-specific service configurations
  - Services that run on dedicated servers