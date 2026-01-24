# NixOS Configuration Validation Protocols

## Timeout Prevention Strategies for Flake-Based Workflows

### Root Cause Analysis

The timeouts occur because:

1. **Nix flake evaluation** tries to evaluate ALL configurations in the repository
2. **Cross-references** between systems (like `self.nixosConfigurations.data-storage.config.services.prometheus.port`) create dependency chains
3. **Resource-intensive operations** like `nix flake check` trigger massive evaluations
4. **Missing dependencies** or syntax errors cause cascading failures across all systems

### Prevention Strategies

#### 1. Targeted Flake Evaluation
```bash
# ✅ Evaluate single configuration only
timeout 30 nix eval --expr 'let flake = builtins.getFlake "."; 
  in flake.nixosConfigurations.cortex-alpha.config.services.nginx.enable'

# ✅ Check specific attribute with timeout
timeout 30 nix eval --expr 'let flake = builtins.getFlake "."; 
  in flake.nixosConfigurations.cortex-alpha.config.services.nginx.virtualHosts' \
  2>/dev/null | head -20
```

#### 2. Flake Check with Filtering
```bash
# ✅ Filter output to relevant errors only
timeout 60 nix flake check --no-build 2>&1 | \
  grep -E "(cortex-alpha|error:|syntax error)" | \
  head -10

# ✅ Exit immediately on cortex-alpha errors
timeout 60 nix flake check --no-build 2>&1 | \
  grep -q "cortex-alpha.*error" && echo "FAIL" || echo "PASS"
```

#### 3. Staged Validation Approach
```bash
# Stage 1: Test individual components
timeout 15 nix eval --expr 'let 
  flake = builtins.getFlake ".";
  lib = import <nixpkgs/lib>;
in 
  (import ./lib/mkProxyPass.nix lib).mkProxyPass [
    { name = "test"; proxyPass = "http://127.0.0.1:80"; }
  ]'

# Stage 2: Test integration with mocked dependencies  
timeout 15 nix eval --expr '
  let
    lib = import <nixpkgs/lib>;
    flake = builtins.getFlake ".";
    mockSelf = {
      nixosConfigurations.data-storage.config.services.prometheus.port = "9090";
      nixosConfigurations.data-storage.config.services.grafana.settings.server.http_port = "3000";
    };
  in (import ./lib/mkProxyPass.nix lib).mkProxyPass [
    { name = "test.johnbargman.net"; 
      proxyPass = "http://10.88.127.3:80"; }
  ]'

# Stage 3: Full configuration only if stages pass
timeout 30 nix eval --expr 'let flake = builtins.getFlake "."; 
  in builtins.attrNames flake.nixosConfigurations.cortex-alpha.config.services.nginx.virtualHosts'
```

#### 4. Dependency Decoupling Strategy
```bash
# ✅ Create test with isolated dependencies
nix eval --expr '
  let
    lib = import <nixpkgs/lib>;
    mockSelf = {
      nixosConfigurations = {
        data-storage.config.services = {
          prometheus.port = "9090";
          grafana.settings.server.http_port = "3000";
        };
      };
    };
    proxyConfigs = [
      { name = "prometheus.johnbargman.net"; 
        proxyPass = "http://10.88.127.3:${toString mockSelf.nixosConfigurations.data-storage.config.services.prometheus.port}"; }
      { name = "grafana.johnbargman.net";
        proxyPass = "http://10.88.127.3:${toString mockSelf.nixosConfigurations.data-storage.config.services.grafana.settings.server.http_port}"; }
    ];
  in (import ./lib/mkProxyPass.nix lib).mkProxyPass proxyConfigs'
```

#### 5. Fast Feedback Loop
```bash
# ✅ Immediate syntax validation
nix-instantiate --parse machines/cortex-alpha/default.nix || echo "SYNTAX ERROR"

# ✅ Quick function test
timeout 10 nix eval --expr 'let lib = import <nixpkgs/lib>; 
  in (import ./lib/mkProxyPass.nix lib) { functionTest = true; }' \
  2>/dev/null && echo "FUNC OK" || echo "FUNC FAIL"

# ✅ Only attempt full check if quick tests pass
[ "$SYNTAX_OK" = "true" ] && [ "$FUNC_OK" = "true" ] && \
  timeout 45 nix flake check --no-build 2>&1 | grep -q "cortex-alpha.*error"
```

#### 6. Evaluation Monitoring
```bash
# ✅ Progress indicators during evaluation
timeout 60 bash -c '
  echo "🔍 Evaluating cortex-alpha..."
  if nix eval --expr "let flake = builtins.getFlake \".\"; in flake.nixosConfigurations.cortex-alpha.config.services.nginx.enable" 2>/dev/null; then
    echo "✅ Basic eval passed"
    if nix eval --expr "let flake = builtins.getFlake \".\"; in flake.nixosConfigurations.cortex-alpha.config.services.nginx.virtualHosts" 2>/dev/null | head -5; then
      echo "✅ VirtualHosts eval passed"
    else
      echo "❌ VirtualHosts eval failed"
    fi
  else
    echo "❌ Basic eval failed"
  fi
'
```

### Key Principles

1. **Always Use Timeouts**: Every evaluation command gets `timeout`
2. **Test Incrementally**: Verify components before integration
3. **Mock Dependencies**: Eliminate cross-system dependency chains
4. **Immediate Feedback**: Report success/failure at each step
5. **Fallback Methods**: Use `nix-instantiate` for syntax when evaluation fails
6. **Targeted Filtering**: Only check relevant configuration sections

### Required Validation Protocol

#### For Function Development:
```bash
# 1. Test function in isolation
nix eval --expr 'let lib = import <nixpkgs/lib>; 
  in (import ./lib/newFunction.nix lib).functionName testInput'

# 2. Verify output structure
nix eval --expr '... | builtins.attrNames'

# 3. Test with real data
nix eval --expr '... with realisticConfig'
```

#### For Configuration Changes:
```bash
# 1. Syntax validation first
nix-instantiate --parse machines/target/default.nix

# 2. Import evaluation
nix eval --expr 'import ./machines/target/default.nix { 
  lib = import <nixpkgs/lib>; 
  pkgs = import <nixpkgs>; 
  self = .;
}'

# 3. Only then attempt flake check
nix flake check --no-build 2>&1 | timeout 30 grep -q "target.*error" && echo "FAIL" || echo "PASS"
```

### Alternative Approaches

#### 1. Bypass Flake System (Not Recommended)
```bash
# Work directly with files instead of flake interface
nix-instantiate machines/cortex-alpha/default.nix \
  -I nixpkgs=channel:nixpkgs-unstable \
  -I self=. \
  --arg lib '{ import = <nixpkgs/lib>; }' \
  --arg pkgs 'import <nixpkgs>' \
  --arg self '.'
```

#### 2. Use Nix REPL for Debugging
```bash
# Start REPL with timeout
echo 'let lib = import <nixpkgs/lib>; 
       flake = builtins.getFlake "."; 
  in flake.nixosConfigurations.cortex-alpha.config.services.nginx' | 
timeout 10 nix repl --stdin
```

#### 3. Create Minimal Test Harness
```nix
# test-config.nix - isolated testing
{ lib, pkgs, self }:
let
  targetConfig = import ./machines/cortex-alpha/default.nix { inherit lib pkgs self; };
in {
  test-syntax = targetConfig ? "syntax-valid";
  test-nginx = targetConfig.services.nginx.virtualHosts or {};
  test-proxies = targetConfig.services.nginx.virtualHosts ? {};
}
```

### Summary

This approach maintains required flake interface while preventing cascade timeouts through:
- Incremental validation stages
- Dependency mocking for isolation  
- Time-bounded evaluation commands
- Immediate feedback loops
- Targeted error filtering

---

**Context**: Developed from opencode.ai session on NixOS configuration refactoring, specifically addressing timeout issues that prevented effective validation of nginx proxy abstraction changes in cortex-alpha configuration.