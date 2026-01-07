# NixOS Configuration Troubleshooting Guide

## Critical Issues and Resolution Protocols

### Deprecated networking.useDHCP Configuration

**Symptom**: Warnings about deprecated `networking.useDHCP` option.

**Root Cause**: NixOS has deprecated global `networking.useDHCP` in favor of per-interface configuration.

**Detection Pattern**:
```bash
grep -r "networking\.useDHCP" machines/
```

**Resolution Protocol**:
Replace deprecated configuration:
```nix
# BEFORE (deprecated)
networking.useDHCP = lib.mkDefault true;

# AFTER (current)
networking.interfaces.<interface>.useDHCP = lib.mkDefault true;
```

**Validation**: Run `nix flake check` and verify no deprecation warnings.

### Cross-System Reference Evaluation Failures

**Symptom**: `error: attribute 'config' missing` when referencing other systems.

**Root Cause**: `self.nixosConfigurations` references during evaluation before systems are fully constructed.

**Detection Pattern**:
```nix
# Problematic reference
proxyPass = "http://${self.nixosConfigurations.other-system.config.services.service.port}";
```

**Resolution Protocol**:
Use static configuration or delayed evaluation:
```nix
# Solution 1: Static configuration
proxyPass = "http://10.88.127.3:9090";

# Solution 2: Conditional evaluation with builtins.tryEval
let
  otherConfig = builtins.tryEval self.nixosConfigurations.other-system.config;
in {
  proxyPass = if otherConfig.success
    then "http://${otherConfig.value.services.service.port}"
    else "http://fallback:9090";
}
```

**Debug Command**: `nix eval .#nixosConfigurations.<name>.config.services.<service>`

### WireGuard Peer Configuration Conflicts

**Symptom**: VPN connection failures or routing issues.

**Root Cause**: Incorrect peer public keys, endpoint configuration, or IP conflicts.

**Detection Protocol**:
```bash
# Check peer configuration
nix eval .#nixosConfigurations.<machine>.config.networking.wireguard.interfaces.wireg0.peers

# Validate public keys
for key in secrets/wiregaurd/*_pub; do
  echo "$key: $(cat $key | wc -c) chars"
done
```

**Resolution Steps**:
1. Verify public key format (44 characters, base64)
2. Confirm endpoint DNS resolution
3. Check IP address conflicts in `10.88.127.0/24` range
4. Validate `allowedIPs` configuration

**Recovery Command**:
```bash
# Restart WireGuard interface
sudo systemctl restart wg-quick-wireg0
```

### Secrix Secret Decryption Failures

**Symptom**: `error: attribute 'decrypted' missing` or permission errors.

**Root Cause**: Incorrect secrix configuration or missing encryption keys.

**Detection Pattern**:
```nix
# Problematic usage
privateKeyFile = config.secrix.wrong.path.decrypted.path;
```

**Resolution Protocol**:
```nix
# Correct secrix reference pattern
privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.<machine>.decrypted.path;

# Ensure host public key is configured
secrix.hostPubKey = "ssh-ed25519 AAAAC3...";
```

**Validation**: `secrix decrypt` and verify file permissions.

### Import Path Resolution Errors

**Symptom**: `error: cannot import '<path>', file not found`

**Root Cause**: Incorrect relative import paths or missing files.

**Detection Protocol**:
```bash
# Validate all imports
find . -name "*.nix" -exec nix-instantiate --parse {} \; 2>&1 | grep "cannot import"
```

**Resolution Protocol**:
Verify import paths relative to file location:
```nix
# From machines/cortex-alpha/default.nix
../../services/acme_server.nix    # Correct: relative to machines/cortex-alpha/
../../../lib/wg_peers.nix         # Incorrect: too many ../
```

**Quick Fix**: Use absolute flake paths with `self`:
```nix
# Flake-absolute imports
self + "/services/acme_server.nix"
```

### Firewall Configuration Conflicts

**Symptom**: Service unreachable despite open ports.

**Root Cause**: Interface-specific firewall rules overriding global configuration.

**Detection Pattern**:
```nix
networking.firewall = {
  allowedTCPPorts = [ 80 443 ];  # Global rules
  interfaces = {
    "wireg0".allowedTCPPorts = [ 1108 ];  # Interface-specific
  };
};
```

**Resolution Protocol**:
Merge interface and global rules appropriately:
```nix
networking.firewall = {
  allowedTCPPorts = [ 80 443 ];
  interfaces = {
    "wireg0" = {
      allowedTCPPorts = [ 1108 80 443 ];  # Include global ports
    };
  };
};
```

**Debug Command**: `sudo nft list ruleset` to inspect active rules.

### ZFS Pool Import Failures

**Symptom**: `cannot import pool` during boot.

**Root Cause**: Pool configuration conflicts or hardware changes.

**Detection Protocol**:
```bash
# Check ZFS status
sudo zpool status
sudo zpool import  # List available pools
```

**Resolution Steps**:
1. Verify hardware configuration matches pool
2. Check `boot.zfs.extraPools` configuration
3. Use `zpool import -f <pool>` for forced import
4. Update `networking.hostId` if hardware changed

**Prevention**: Configure pool import in hardware-configuration.nix

### DNS Resolution Issues

**Symptom**: Local DNS queries fail or external resolution broken.

**Root Cause**: dnsmasq configuration conflicts or upstream server issues.

**Detection Protocol**:
```bash
# Test DNS resolution
dig @127.0.0.1 google.com
dig @10.88.127.1 cortex-alpha.local

# Check dnsmasq status
sudo systemctl status dnsmasq
```

**Resolution Protocol**:
Verify dnsmasq configuration:
```nix
services.dnsmasq = {
  settings = {
    server = [ "208.67.220.220" "8.8.8.8" ];  # Upstream servers
    interface = "enp3s0";  # Bind interface
    address = [ "/host.local/10.88.128.1" ];  # Local records
  };
};
```

### Prometheus Exporter Configuration Errors

**Symptom**: Metrics collection failures or permission issues.

**Root Cause**: Incorrect listen addresses or service dependencies.

**Detection Pattern**:
```nix
# Check exporter status
sudo systemctl status prometheus-dnsmasq-exporter

# Test metrics endpoint
curl http://10.88.127.1:3101/metrics
```

**Resolution Protocol**:
Configure appropriate listen addresses and permissions:
```nix
services.prometheus.exporters.dnsmasq = {
  enable = true;
  listenAddress = "10.88.127.1";
  port = 3101;
  leasesPath = "/var/lib/dnsmasq/dnsmasq.leases";
  dnsmasqListenAddress = "10.88.128.1:53";
};
```

### Nixinate Deployment Failures

**Symptom**: `error: unable to connect` or authentication failures.

**Root Cause**: SSH configuration, port conflicts, or network issues.

**Detection Protocol**:
```bash
# Test SSH connection
ssh -p 1108 deploy@target-host

# Check nixinate configuration
nix eval .#nixosConfigurations.<machine>.config._module.args.nixinate
```

**Resolution Steps**:
1. Verify SSH host keys in `flake.nix`
2. Confirm port 1108 availability
3. Check user permissions and sudo access
4. Validate `buildOn` parameter (local/remote)

**Debug Deployment**:
```bash
# Manual deployment test
nix run .#<machine> -- --show-trace
```

### SD Image Build Failures (Aarch64)

**Symptom**: Cross-compilation errors or missing modules.

**Root Cause**: Overlay configuration issues or architecture mismatches.

**Detection Protocol**:
```bash
# Check build logs
nix log /nix/store/<drv-path>

# Validate architecture
nix eval .#packages.aarch64-linux.<image>.meta.platforms
```

**Resolution Protocol**:
Apply appropriate overlays:
```nix
nixpkgs.overlays = [
  (final: super: {
    makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
  })
];
```

**Cross-Compilation Fix**: Ensure `nixpkgs.buildPlatform` and `nixpkgs.hostPlatform` are correctly set.

### Flake Evaluation Performance Issues

**Symptom**: Slow `nix flake check` or `nixos-rebuild` commands.

**Root Cause**: Inefficient configuration evaluation or large import trees.

**Detection Protocol**:
```bash
# Time evaluation
time nix eval .#nixosConfigurations.<machine>.config

# Check import depth
find . -name "*.nix" -exec grep -l "imports" {} \; | head -20
```

**Resolution Protocol**:
1. Use `lib.mkIf` for conditional configuration
2. Minimize cross-system references
3. Cache evaluation results with `nix-store --gc --print-roots`

**Optimization Pattern**:
```nix
# BEFORE: Always evaluated
services.expensiveService = { ... };

# AFTER: Conditionally evaluated
services.expensiveService = lib.mkIf config.myModule.enable { ... };
```

### Determinate Integration Conflicts

**Symptom**: Build failures with Determinate Systems integration.

**Root Cause**: Version conflicts or incorrect module ordering.

**Detection Pattern**:
```nix
# Check Determinate version
determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
```

**Resolution Protocol**:
Ensure Determinate modules are applied correctly:
```nix
modules = commonModules ++ (if dt then [ determinate.nixosModules.default ] else []) ++ extraModules;
```

**Validation**: Test builds without Determinate first, then add incrementally.

### IPv6 Configuration Issues

**Symptom**: IPv6 connectivity problems or routing failures.

**Root Cause**: Incomplete IPv6 setup or disabled forwarding.

**Detection Protocol**:
```bash
# Check IPv6 status
ip -6 addr show
ip -6 route show

# Test IPv6 connectivity
ping6 google.com
```

**Resolution Protocol**:
Enable IPv6 forwarding and configuration:
```nix
boot.kernel.sysctl = {
  "net.ipv6.conf.all.forwarding" = true;
  "net.ipv6.conf.all.accept_ra" = 2;
};
```

**Network Configuration**: Configure IPv6 addresses and routes in `networking.interfaces`.

## Advanced Debugging Techniques

### Interactive Nix Evaluation

```bash
# Enter nix repl
nix repl

# Load flake
:lf .

# Inspect configuration
nixosConfigurations.cortex-alpha.config.services.nginx.virtualHosts
```

### Build Log Analysis

```bash
# Get derivation path
nix derivation show .#nixosConfigurations.<machine>.config.system.build.toplevel

# View build logs
nix log /nix/store/<drv-path>
```

### Configuration Diff Analysis

```bash
# Compare configurations
nix eval --json .#nixosConfigurations.machine1.config | jq . > config1.json
nix eval --json .#nixosConfigurations.machine2.config | jq . > config2.json
diff config1.json config2.json
```

### Memory and Performance Profiling

```bash
# Profile evaluation
env NIX_SHOW_STATS=1 nix eval .#nixosConfigurations.<machine>.config 2>&1 | grep -E "(alloc|time)"

# Check for infinite recursion
timeout 30 nix eval .#nixosConfigurations.<machine>.config.networking.hostName
```

## Emergency Recovery Procedures

### Boot into Rescue Environment

1. Boot from installation media
2. Mount ZFS pools: `zpool import -a`
3. Chroot into system: `nixos-enter`
4. Repair configuration and rebuild

### Network Recovery

```bash
# Manual network configuration
ip addr add 10.88.127.1/24 dev eth0
ip route add default via <gateway>
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### Service Recovery Commands

```bash
# Restart critical services
sudo systemctl restart dnsmasq nginx wireguard-wg0

# Check service status
sudo systemctl status --all | grep -E "(failed|error)"
```

This guide provides systematic approaches to diagnose and resolve common NixOS configuration issues encountered in complex, multi-system deployments.