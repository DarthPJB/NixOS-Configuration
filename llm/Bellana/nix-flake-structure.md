# Nix Flake Structure Analysis - Bellana Domain Expertise

## Repository Flake Architecture

### Input Structure
- **Multiple nixpkgs channels**: stable (0), unstable (weekly/0), legacy (23.05)
- **Custom flakes**: secrix, nixinate, parsecgaming, hyprland, nixos-hardware
- **Determinate Systems**: Integrated for deployment determinism

### Output Organization
- **nixosConfigurations**: Machine-specific systems with architecture builders (mkX86_64, mkAarch64)
- **packages**: Image builders for libvirt and SD card images
- **apps**: Deployment utilities and secrix integration
- **checks**: deadnix and formatting validation

### Builder Patterns
```nix
mkX86_64 = name: hostname: { extraModules ? [], ... }:
  nixpkgs_stable.lib.nixosSystem {
    system = "x86_64-linux";
    modules = commonModules ++ extraModules ++ [
      ./machines/${name}
      { networking.hostName = hostname; }
    ];
  };
```

Key patterns:
- Unified commonModules across all systems
- Global args propagation via _module.args
- Architecture-specific overlays and configurations
- Determinate integration via dt flag

### Module Composition Strategy
- Common modules: secrix, configuration.nix, allowUnfree, stateVersion
- Extra modules: Hardware-specific, service additions, user configurations
- Global args: self reference, unstable packages via _module.args.unstable

## Insights for Nix Engineering

### Reproducibility Considerations
- Explicit input pinning with flake.lock
- Separate stable/unstable channels with controlled unstable propagation
- Determinate integration for deployment consistency

### Scaling Patterns
- Builder functions reduce duplication across similar architectures
- Modular extraModules allow composition without inheritance
- Image builders leverage nixos/lib/make-disk-image.nix for virtualization

### Deployment Integration
- nixinate for remote deployment with SSH/port configuration
- deploy-all app for batch deployment with jq filtering
- Secrix for secret management with host-specific keys

### Cross-Architecture Support
- x86_64-linux: Full systems with optional virtualization
- aarch64-linux: SD image builds with minimal profiles, hardware-specific modules
- armv7l-linux: Specialized configurations for older ARM devices

## Best Practices Observed

### Input Management
- Use follows for consistent versions across dependencies
- Separate channels for stable production vs. unstable features
- Custom flakes for domain-specific tooling (gaming, hardware, secrets)

### Module Organization
- Common modules first, then architecture-specific, then machine-specific
- Global args for cross-system references and unstable packages
- Hardware configurations separated from logical configuration

### Output Hygiene
- Consistent naming: hostname matches configuration name
- Clear separation: terminals, home lab, virtualized, remote systems
- Image outputs for different deployment scenarios (libvirt, SD cards)