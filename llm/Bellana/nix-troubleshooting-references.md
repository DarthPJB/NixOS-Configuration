# Nix Troubleshooting References - Bellana Analysis

## Common Evaluation Errors

### Import Path Issues
**Error Pattern:**
```
error: getting status of '/path/to/missing/file.nix': No such file or directory
```

**Root Causes:**
- Relative import paths incorrect from machine location
- Files moved or renamed without updating imports
- Case sensitivity in file paths

**Resolution:**
```bash
# Check file existence
find . -name "*.nix" | grep target-file

# Validate import syntax
nix flake check
```

### Syntax Errors
**Error Pattern:**
```
error: syntax error, unexpected '}', expecting ';'
```

**Common Issues:**
- Missing semicolons after attribute sets
- Unmatched braces or brackets
- Incorrect list vs. attribute set syntax

**Debug Commands:**
```bash
# Syntax validation
nix-instantiate --parse path/to/file.nix

# Full flake evaluation
nix flake check
```

## Build Failures

### Package Availability
**Error Pattern:**
```
error: attribute 'missing-package' missing
```

**Root Causes:**
- Package not in specified nixpkgs channel
- Architecture mismatch (x86_64 vs aarch64)
- Unstable package not propagated correctly

**Solutions:**
```nix
# Check package existence
nix search nixpkgs package-name

# Use unstable propagation
_module.args.unstable = import nixpkgs_unstable { ... };
```

### Derivation Issues
**Error Pattern:**
```
error: build of '/nix/store/...-package.drv' failed
```

**Debugging:**
```bash
# View build logs
nix log /nix/store/...-package.drv

# Build with verbose output
nix build --verbose
```

## Network Configuration Issues

### WireGuard Connectivity
**Common Problems:**
- MTU mismatches causing fragmentation
- Firewall rules blocking traffic
- Peer configuration inconsistencies

**Diagnostic Commands:**
```bash
# Check interface status
ip a show wireg0

# Test connectivity
ping 10.88.127.1

# View WireGuard status
wg show
```

### Port Conflicts
**Error Pattern:**
```
error: the option `networking.firewall.allowedTCPPorts' has conflicting definitions
```

**Resolution:**
- Use `lib.mkForce` for intentional overrides
- Check for duplicate port declarations
- Review import order and composition

## Secret Management Issues

### Secrix Decryption Failures
**Error Pattern:**
```
error: getting status of '/run/secrets/...': Permission denied
```

**Root Causes:**
- Incorrect secrix configuration
- Missing host public keys
- Decryption service not running

**Verification:**
```bash
# Check secrix status
systemctl status secrix

# Validate key setup
ls -la /run/secrets/
```

### Path Resolution
**Common Issue:**
References to `config.secrix.<path>` failing evaluation

**Solutions:**
- Ensure secrix module is imported in commonModules
- Verify secret file existence in secrets/ directory
- Check encryption with correct master key

## Cross-System Reference Issues

### Self Reference Errors
**Error Pattern:**
```
error: attribute 'some-config' missing at self.nixosConfigurations
```

**Root Causes:**
- Configuration name mismatch
- Circular dependencies in evaluation
- Missing configurations in flake outputs

**Debugging:**
```bash
# List available configurations
nix flake show | grep nixosConfigurations

# Evaluate specific config
nix eval .#nixosConfigurations.config-name
```

## Performance Issues

### Evaluation Slowdown
**Symptoms:**
- `nix flake check` taking excessive time
- Large memory usage during evaluation

**Causes:**
- Inefficient attribute set operations
- Excessive string interpolation in hot paths
- Large import trees

**Optimizations:**
```nix
# Use builtins.mapAttrs for transformations
# Minimize string operations
# Use lib.mkIf for conditional evaluation
```

### Build Dependencies
**Issue:** Unnecessary rebuilds of dependent systems

**Solutions:**
- Minimize shared dependencies
- Use specific package versions
- Separate build environments

## Architecture-Specific Issues

### aarch64 Cross-Compilation
**Common Errors:**
- Host platform mismatches
- Missing cross-compilation toolchains

**Configuration:**
```nix
# Ensure correct platform settings
nixpkgs.hostPlatform = "aarch64-linux";
nixpkgs.buildPlatform = "x86_64-linux";
```

### ARM Image Building
**Issues:**
- SD image creation failures
- Bootloader configuration errors

**Verification:**
```bash
# Check image contents
nix build .#packages.aarch64-linux.system-image
ls -la result/
```

## Deployment Issues

### nixinate Failures
**Error Pattern:**
```
error: unable to connect to host
```

**Diagnostics:**
- Verify SSH connectivity on port 1108
- Check host keys in flake configuration
- Validate user permissions

### Batch Deployment
**Issue:** deploy-all script failures

**Debugging:**
```bash
# Test individual deployment
nix run .#target-system

# Check system filtering
nix flake show | jq '.apps."x86_64-linux"'
```

## Flake Input Problems

### Lock File Issues
**Error:** Lock file outdated or corrupted

**Resolution:**
```bash
# Update lock file
nix flake update

# Re-lock specific input
nix flake lock --update-input nixpkgs
```

### Input Following
**Issue:** inputs not following as expected

**Verification:**
```nix
# Check follows declarations
inputs.nixpkgs_stable.follows = "nixpkgs";
```

## Validation Commands

### Pre-Commit Checks
```bash
# Full validation suite
nix flake check

# Dead code detection
nix run .#deadnix

# Formatting validation
nix run .#formatting
```

### Runtime Debugging
```bash
# Interactive evaluation
nix repl

# Specific output evaluation
nix eval .#nixosConfigurations.hostname.config.services.openssh.enable

# Build testing
nixos-rebuild build --flake .#hostname
```

## Emergency Recovery

### Boot Issues
- Use installation media to chroot
- Revert to previous generation
- Check hardware-configuration.nix

### Configuration Rollback
```bash
# List generations
nixos-rebuild list-generations

# Switch to specific generation
nixos-rebuild switch --rollback
```

## Monitoring and Alerting

### Log Analysis
- Journalctl for service failures
- Nix build logs for derivation issues
- Prometheus metrics for system health

### Proactive Monitoring
- Regular flake checks in CI/CD
- Automated deployment testing
- Configuration drift detection