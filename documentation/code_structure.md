# Code Structure

This document explains how NixOS configurations are organized in this repository.

## Module Organization
- **Flake-based**: All configurations use Nix flakes for reproducibility
- **Modular imports**: Configurations import from `environments/`, `services/`, and `lib/`
- **Machine-specific**: Each machine in `machines/` has its own config importing shared modules

## File Patterns
- **Options first**: Each module starts with `options` block defining configurable settings
- **Config second**: Followed by `config` block implementing the logic
- **Relative imports**: Use paths like `../../lib/enable-wg.nix` for local modules

## Key Conventions
- **CamelCase variables**: For attribute names (e.g., `enableService`)
- **Kebab-case files**: Filenames use hyphens (e.g., `nextcloud.nix`)
- **Conditional logic**: Use `lib.mkIf` for optional configurations
- **Default values**: Apply with `lib.mkDefault` for overridable settings

## Common Patterns
- **Package lists**: Group with `with pkgs; [ package1 package2 ]`
- **Service enabling**: `services.myService.enable = true;`
- **Attribute sets**: Format as multi-line for readability
- **String interpolation**: Use `${variable}` for dynamic strings

## Import Hierarchy
- Machines import environments for software stacks
- Environments may import services for specific features
- Libraries provide utilities used across modules
- Modifiers add global system features

## Best Practices
- Keep modules focused on single responsibilities
- Use descriptive names matching purpose
- Validate with `nix flake check` before committing
- Format code with `nix fmt` for consistency