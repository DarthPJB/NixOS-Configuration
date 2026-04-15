# CI/CD Implementation Guide
## Exact Code Changes for Seven-of-Nine's Corrections

### Quick Reference Commands
```bash
# After making changes:
nix run .#generate-ci-workflow > .github/workflows/ci.yml
nix run .#validate-ci-workflow
```

---

## 🔧 **Change 1: Update Machine Lists (Lines 7-27)**

### Current Code:
```nix
x86Machines = [
  "terminal-zero"
  "terminal-nx-01"
  "cortex-alpha"
  "local-nas"
  "alpha-one"
  "alpha-two"
  "alpha-three"
  "LINDA"
  "gaming-host-1"
  "remote-worker"
  "storage-array"
  "remote-builder"
];

armMachines = [
  "display-0"
  "display-1"
  "display-2"
  "print-controller"
];
```

### Replace With:
```nix
x86Machines = [
  "terminal-zero"
  "terminal-nx-01"
  "cortex-alpha"
  "local-nas"
  "alpha-one"
  "alpha-two"
  "alpha-three"
  "LINDA"
  "gaming-host-1"
  "remote-worker"
  "storage-array"
  "remote-builder"
  "local-worker"  # Added: missing machine
  "obs-box"       # Added: missing machine
];

armMachines = [
  "display-0"
  "display-1"
  "display-2"
  "print-controller"
  "beta-one"      # Added: armv7l-linux machine
];
```

---

## 🔧 **Change 2: Add Job Dependencies (Lines 64, 94, 156)**

### build-x86 Job (Line 64):
**Add after `name = "Build x86_64 Configurations";`:**
```nix
needs = [ "validation" "security" ];  # Added: enforce job hierarchy
```

### build-arm Job (Line 94):
**Add after `name = "Build ARM Configurations";`:**
```nix
needs = [ "validation" "security" ];  # Added: enforce job hierarchy
```

### deploy-prep Job (Line 156):
**Add after `name = "Deployment Preparation";`:**
```nix
needs = [ "validation" "security" "build-x86" "build-arm" ];  # Added: full dependency chain
```

---

## 🔧 **Change 3: Fix Manual Dispatch Logic (Lines 156-190)**

### Current Code (Lines 156-190):
```nix
deploy-prep = {
  name = "Deployment Preparation";
  runs-on = "ubuntu-latest";
  "if" = "github.event_name == 'workflow_dispatch'";
  strategy = {
    matrix = {
      machine = x86Machines ++ armMachines;
    };
  };
  steps = [
    # ... steps ...
  ];
};
```

### Replace With:
```nix
deploy-prep = {
  needs = [ "validation" "security" "build-x86" "build-arm" ];
  name = "Deploy - ${{ github.event.inputs.machine }}";
  runs-on = "ubuntu-latest";
  "if" = "github.event_name == 'workflow_dispatch'";
  # REMOVED: strategy.matrix - build only selected machine
  steps = [
    {
      name = "Checkout";
      uses = "actions/checkout@v4";
    }
    {
      name = "Install Nix";
      uses = "DeterminateSystems/nix-installer-action@main";
    }
    {
      name = "Setup Magic Nix Cache";
      uses = "DeterminateSystems/magic-nix-cache-action@main";
    }
    {
      name = "Build configuration";
      # CHANGED: Use selected machine from input
      run = "nixos-rebuild build --flake .#${{ github.event.inputs.machine }}";
    }
    {
      name = "Test deployment";
      if = "github.event.inputs.action == 'test'";
      run = "nix run .#${{ github.event.inputs.machine }}";
    }
    {
      name = "Deploy to machine";
      if = "github.event.inputs.action == 'deploy'";
      run = "nix run .#${{ github.event.inputs.machine }} -- switch";
    }
    {
      name = "Upload deployment logs";
      if = "always()";  # Upload even if deployment fails
      uses = "actions/upload-artifact@v4";
      with = {
        name = "deploy-${{ github.event.inputs.machine }}-logs";
        path = "/tmp/deploy-*.log";
        retention-days = "30";
      };
    }
  ];
};
```

---

## 🔧 **Change 4: Add Artifact Handling (Lines 73-90, 103-120)**

### Add to build-x86 steps (after line 89):
```nix
{
  name = "Upload build artifact";
  uses = "actions/upload-artifact@v4";
  with = {
    name = "${{ matrix.machine }}-config";
    path = "result/";
    retention-days = "7";
  };
}
```

### Add to build-arm steps (after line 119):
```nix
{
  name = "Upload build artifact";
  uses = "actions/upload-artifact@v4";
  with = {
    name = "${{ matrix.machine }}-config";
    path = "result/";
    retention-days = "7";
  };
}
```

---

## 🔧 **Change 5: Enhance Security Scanning (Lines 124-153)**

### Current Code (Lines 124-153):
```nix
security = {
  name = "Security Scan";
  runs-on = "ubuntu-latest";
  steps = [
    # ... steps ...
  ];
};
```

### Replace With:
```nix
security = {
  name = "Security Scan";
  runs-on = "ubuntu-latest";
  steps = [
    {
      name = "Checkout";
      uses = "actions/checkout@v4";
      with = {
        fetch-depth = "0";  # Full history for secret scanning
      };
    }
    {
      name = "Install Nix";
      uses = "DeterminateSystems/nix-installer-action@main";
    }
    {
      name = "Install Gitleaks";
      run = "nix-shell -p gitleaks --run 'gitleaks version'";
    }
    {
      name = "Run Gitleaks secret scanning";
      run = "nix-shell -p gitleaks --run 'gitleaks detect --source . --verbose'";
    }
    {
      name = "Check for plaintext secrets in Nix files";
      run = ''
        echo "Checking for potential secrets in Nix files..."
        
        # Enhanced pattern matching
        PATTERNS="password|secret|key|token|api_key|apikey|access_key|private_key"
        EXCLUDES="secrix|public|pub|README|documentation|\.pub$|_pub$"
        
        if grep -rE "$PATTERNS" --include="*.nix" . | grep -vE "$EXCLUDES"; then
          echo "⚠️  Potential secrets found in Nix files"
          echo "Review the above matches manually"
          # Don't fail - just warn for now
        else
          echo "✅ No obvious secrets found in Nix files"
        fi
      '';
    }
    {
      name = "Validate secrix configuration";
      run = "nix run .#secrix -- --help";
    }
    {
      name = "Check for hardcoded IPs";
      run = ''
        echo "Checking for hardcoded IP addresses..."
        # Look for IP patterns but exclude documentation
        if grep -rE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" --include="*.nix" . | grep -v "10.88.127" | grep -v "127.0.0.1" | grep -v "documentation"; then
          echo "⚠️  Non-standard IP addresses found (excluding VPN range)"
        else
          echo "✅ IP addresses appear standard"
        fi
      '';
    }
  ];
};
```

---

## 🔧 **Change 6: ARM Performance Notes (Optional)**

### Add to build-arm job (after line 96):
```nix
# TODO: Replace with self-hosted ARM runner for better performance
# Current: QEMU emulation on x86_64 runners (slow)
# Future: runs-on: [self-hosted, linux, ARM64]
"timeout-minutes" = "60";  # Prevent infinite QEMU builds
```

### Add QEMU configuration step (optional):
```nix
{
  name = "Configure QEMU for ARM";
  run = ''
    sudo apt-get update
    sudo apt-get install -y qemu-user-static binfmt-support
    sudo update-binfmts --enable qemu-arm
    sudo update-binfmts --enable qemu-aarch64
  '';
}
```

---

## 📋 **Validation Checklist**

After making all changes:

1. **Syntax Check:**
   ```bash
   nix run .#generate-ci-workflow > .github/workflows/ci.yml
   nix run .#validate-ci-workflow
   ```

2. **Job Dependencies:**
   - [ ] `build-x86` has `needs: [validation, security]`
   - [ ] `build-arm` has `needs: [validation, security]`
   - [ ] `deploy-prep` has `needs: [validation, security, build-x86, build-arm]`

3. **Machine Coverage:**
   - [ ] `x86Machines` includes 14 machines (12 original + 2 new)
   - [ ] `armMachines` includes 5 machines (4 original + 1 new)
   - [ ] `workflow_dispatch` inputs include all machines

4. **Artifact Handling:**
   - [ ] `build-x86` has artifact upload
   - [ ] `build-arm` has artifact upload
   - [ ] `deploy-prep` has log upload

5. **Security Enhancements:**
   - [ ] Gitleaks installation and execution
   - [ ] Enhanced pattern matching
   - [ ] IP address validation

6. **Manual Dispatch:**
   - [ ] Uses `${{ github.event.inputs.machine }}`
   - [ ] No matrix strategy
   - [ ] Conditional steps for build/test/deploy

---

## 🚀 **Deployment Steps**

1. **Make Changes:** Edit `ci.nix` with above modifications
2. **Regenerate:** `nix run .#generate-ci-workflow > .github/workflows/ci.yml`
3. **Validate:** `nix run .#validate-ci-workflow`
4. **Test Locally:** Review generated YAML
5. **Commit:**
   ```bash
   git add ci.nix .github/workflows/ci.yml
   git commit -m "ci: fix job dependencies, machine registry, and manual dispatch"
   git push origin ci/fix-job-dependencies
   ```
6. **Create PR:** Test in GitHub Actions
7. **Monitor:** Verify all jobs execute correctly

---

**Status:** READY FOR IMPLEMENTATION  
**Estimated Time:** 1-2 hours  
**Risk:** LOW (incremental improvements)