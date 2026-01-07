# Nix Configuration Insights - Bellana Expertise

## Architecture-Specific Patterns

### x86_64-linux Systems
**Characteristics:**
- Full NixOS installations with EFI boot
- Optional virtualization (libvirtd, virtualbox)
- Hardware acceleration (NVIDIA, CUDA)
- Remote deployment via nixinate

**Common Configurations:**
- Boot: systemd-boot with EFI variables
- Networking: WireGuard VPN with static IPs (10.88.127.X)
- Services: SSH, monitoring exporters, domain services

### aarch64-linux Systems
**Characteristics:**
- SD card images for Raspberry Pi variants
- Minimal profiles with hardware-specific modules
- Cross-compilation from x86_64 builders
- Compressed/uncompressed image options

**Key Differences:**
- `nixpkgs.hostPlatform = "aarch64-linux"`
- SD image modules instead of full installations
- Disabled documentation and base profiles
- Hardware overlays for Pi firmware

### armv7l-linux Systems
**Characteristics:**
- Legacy ARM support for older devices
- Custom SD image builders
- Minimal service footprints

## Service Integration Patterns

### Monitoring Stack (Prometheus/Grafana)
```nix
services.prometheus.scrapeConfigs = [
  {
    job_name = "node";
    static_configs = [{
      targets = map (cfg: "${cfg.config.networking.wireguard.interfaces.wireg0.ips[0].split("/")[0]}:${toString cfg.config.services.prometheus.exporters.node.port}") (attrValues self.nixosConfigurations);
    }];
  }
];
```

**Insights:**
- Cross-system configuration references
- Dynamic target generation from nixosConfigurations
- Label propagation for identification

### Networking and Security
- **WireGuard VPN**: Centralized peer management via wg_peers.nix
- **Firewall**: Interface-specific rules for WireGuard, external access
- **NAT**: Port forwarding for gaming, services
- **DNS**: dnsmasq for local resolution and DHCP

### Secret Management
- **Secrix Integration**: Encrypted secrets with host-specific keys
- **Path References**: `config.secrix.<service>.<secret>.decrypted.path`
- **Key Management**: Master keys for encryption/decryption

## Deployment and Scaling Patterns

### Remote Deployment
- **nixinate**: SSH-based deployment with custom ports (1108)
- **Batch Operations**: deploy-all script with system filtering
- **Build Strategies**: local, remote, or distributed building

### Image Building
- **Libvirt Images**: QEMU-compatible disk images
- **SD Images**: Raspberry Pi installation media
- **Compression Options**: Uncompressed for faster writes

## Best Practices Derived

### Modularity Principles
1. **Single Responsibility**: Each module handles one logical concern
2. **Composition over Inheritance**: Use imports and extraModules
3. **Parameterization**: Pass configuration via function arguments
4. **Cross-System References**: Leverage self.nixosConfigurations for dynamic configs

### Configuration Hygiene
1. **Explicit Dependencies**: Declare all inputs in flake.nix
2. **Version Pinning**: Use flake.lock for reproducibility
3. **Type Safety**: Define options with lib.types
4. **Conditional Logic**: Use lib.mkIf for feature toggles

### Performance Considerations
1. **Evaluation Efficiency**: Minimize string operations in hot paths
2. **Caching**: Leverage Nix store for reproducible builds
3. **Parallel Building**: Support for distributed compilation
4. **Minimal Closures**: Careful package selection for embedded systems

### Security Patterns
1. **Encrypted Secrets**: Never commit plaintext credentials
2. **Firewall Rules**: Interface-specific access control
3. **Service Isolation**: Bind services to internal interfaces
4. **Update Management**: Controlled nixpkgs channel updates

## Troubleshooting Reference Patterns

### Common Issues
- **Evaluation Errors**: Check import paths and syntax
- **Build Failures**: Verify package availability in channels
- **Secret Access**: Ensure secrix decryption paths
- **Network Conflicts**: Check WireGuard IP allocation

### Debugging Approaches
- **nix repl**: Interactive evaluation testing
- **nix eval**: Specific output evaluation
- **nix log**: Build failure analysis
- **flake check**: Pre-deployment validation

## Evolution Patterns

### Version Management
- **Stable Channel**: Production systems
- **Unstable Propagation**: Controlled feature access
- **Legacy Support**: Compatibility for older configurations

### Hardware Adaptation
- **nixos-hardware**: Community-maintained hardware configurations
- **Custom Modules**: Repository-specific hardware support
- **Cross-Platform**: Unified configuration across architectures

### Service Convergence
- **Dynamic Configuration**: Services that discover other systems
- **Centralized Management**: Router/gateway as service hub
- **Monitoring Integration**: Unified observability across fleet