# CI/CD Correction Plan
## Addressing Seven-of-Nine's Critical Findings

### Executive Summary
The current CI configuration has **6 critical flaws** that will cause resource waste, operational friction, and security vulnerabilities. This plan details exact modifications needed to achieve production-ready status.

---

## 🔴 **Critical Issues & Solutions**

### **Issue 1: Missing Job Dependencies (Resource Waste)**
**Problem:** Build jobs execute simultaneously with validation, wasting 30-60 minutes on syntax errors.

**Solution:** Add `needs` keywords to enforce job hierarchy.

```nix
# In ciJobs definition:
build-x86 = {
  needs = [ "validation" "security" ];  # ADD THIS
  name = "Build x86_64 Configurations";
  # ...
};

build-arm = {
  needs = [ "validation" "security" ];  # ADD THIS
  name = "Build ARM Configurations";
  # ...
};

deploy-prep = {
  needs = [ "validation" "security" "build-x86" "build-arm" ];  # ADD THIS
  # ...
};
```

### **Issue 2: Incomplete Machine Registry**
**Problem:** Only 16/19 machines tracked. Missing: `beta-one`, `obs-box`, `local-worker`.

**Solution:** Update machine lists in `ci.nix`:

```nix
# Update x86Machines list:
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
  "local-worker"  # ADD THIS
  "obs-box"       # ADD THIS
];

# Update armMachines list:
armMachines = [
  "display-0"
  "display-1"
  "display-2"
  "print-controller"
  "beta-one"      # ADD THIS (armv7l-linux)
];
```

### **Issue 3: Flawed Manual Dispatch Logic**
**Problem:** `deploy-prep` builds ALL machines instead of selected one.

**Solution:** Replace matrix strategy with conditional single-machine build:

```nix
# Replace deploy-prep job definition:
deploy-prep = {
  needs = [ "validation" "security" "build-x86" "build-arm" ];
  name = "Deploy - ${{ github.event.inputs.machine }}";
  runs-on = "ubuntu-latest";
  "if" = "github.event_name == 'workflow_dispatch'";
  # REMOVE strategy.matrix - build only selected machine
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
      # Use selected machine from input, not matrix
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
  ];
};
```

### **Issue 4: No Artifact Preservation**
**Problem:** Build outputs and logs are lost after job completion.

**Solution:** Add artifact upload steps to all build jobs:

```nix
# Add to build-x86 and build-arm steps:
{
  name = "Upload build artifact";
  uses = "actions/upload-artifact@v4";
  with = {
    name = "\${{ matrix.machine }}-config";
    path = "result/";
    retention-days = "7";
  };
}

# Add to deploy-prep step:
{
  name = "Upload deployment logs";
  if = "always()";  # Upload even if deployment fails
  uses = "actions/upload-artifact@v4";
  with = {
    name = "deploy-\${{ github.event.inputs.machine }}-logs";
    path = "/tmp/deploy-*.log";
    retention-days = "30";
  };
}
```

### **Issue 5: ARM Performance Issues**
**Problem:** ARM builds on x86_64 runners use slow QEMU emulation.

**Solution:** Add ARM runner configuration:

```nix
# Add to build-arm job:
build-arm = {
  needs = [ "validation" "security" ];
  name = "Build ARM Configurations";
  runs-on = "ubuntu-latest";  # Keep for now, but add note
  # Add timeout to prevent long QEMU builds
  "timeout-minutes" = "60";
  strategy = {
    fail-fast = false;
    matrix = {
      machine = armMachines;
    };
  };
  steps = [
    # ... existing steps ...
    {
      name = "Configure QEMU for ARM";
      run = ''
        sudo apt-get update
        sudo apt-get install -y qemu-user-static binfmt-support
        sudo update-binfmts --enable qemu-arm
        sudo update-binfmts --enable qemu-aarch64
      '';
    }
    {
      name = "Build configuration";
      run = "nixos-rebuild build --flake .#\${{ matrix.machine }}";
    }
  ];
};

# Add comment for future improvement:
# TODO: Replace with self-hosted ARM runner for better performance
# Consider: runs-on: [self-hosted, linux, ARM64]
```

### **Issue 6: Weak Security Scanning**
**Problem:** Primitive grep checks miss sophisticated secrets.

**Solution:** Enhance security scanning:

```nix
# Replace security job steps:
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

## 📋 **Implementation Steps**

### **Step 1: Update Machine Lists**
1. Edit `ci.nix` lines 7-27
2. Add missing machines to `x86Machines` and `armMachines`
3. Update workflow_dispatch inputs to include new machines

### **Step 2: Add Job Dependencies**
1. Add `needs` field to `build-x86`, `build-arm`, `deploy-prep`
2. Ensure proper dependency chain: validation → security → builds → deploy

### **Step 3: Fix Manual Dispatch**
1. Replace `deploy-prep` matrix strategy with conditional logic
2. Use `${{ github.event.inputs.machine }}` instead of matrix
3. Add conditional steps for build/test/deploy actions

### **Step 4: Add Artifact Handling**
1. Add `actions/upload-artifact@v4` to all build jobs
2. Configure retention periods (7 days for builds, 30 for logs)
3. Add `if: always()` for failure logging

### **Step 5: Enhance Security Scanning**
1. Add Gitleaks installation and execution
2. Improve pattern matching for secrets
3. Add IP address validation
4. Maintain backward compatibility with existing checks

### **Step 6: ARM Performance Notes**
1. Add QEMU configuration step
2. Set appropriate timeouts (60 minutes)
3. Document future self-hosted runner plans

---

## 🧪 **Testing Plan**

### **Local Testing**
```bash
# 1. Update ci.nix with corrections
# 2. Regenerate workflow
nix run .#generate-ci-workflow > .github/workflows/ci.yml

# 3. Validate syntax
nix run .#validate-ci-workflow

# 4. Check YAML structure
cat .github/workflows/ci.yml | head -100
```

### **GitHub Actions Testing**
1. Create test branch: `git checkout -b ci/fix-job-dependencies`
2. Push changes: `git push origin ci/fix-job-dependencies`
3. Create PR to trigger CI
4. Verify:
   - Validation runs first
   - Security scan runs second
   - Builds only run if validation passes
   - Manual dispatch builds only selected machine
   - Artifacts are uploaded

---

## 📊 **Expected Outcomes**

### **Before Corrections:**
- **Resource Waste:** 16 parallel builds on syntax errors
- **Incomplete Coverage:** 3 machines not tested
- **Manual Deploy:** Builds all 16 machines for single deployment
- **Lost Artifacts:** No build outputs preserved
- **Slow ARM Builds:** QEMU emulation without optimization
- **Weak Security:** Primitive grep checks

### **After Corrections:**
- **Resource Efficiency:** Builds only run after validation passes
- **Complete Coverage:** All 19 machines tested
- **Precise Deployment:** Single machine builds for manual dispatch
- **Artifact Preservation:** 7-day retention for builds, 30-day for logs
- **Optimized ARM:** QEMU configuration with timeouts
- **Enhanced Security:** Gitleaks + pattern matching + IP validation

---

## 🚀 **Implementation Priority**

1. **HIGH PRIORITY (Immediate):**
   - Add job dependencies (Issue 1)
   - Fix manual dispatch logic (Issue 3)

2. **MEDIUM PRIORITY (Next Sprint):**
   - Complete machine registry (Issue 2)
   - Add artifact handling (Issue 4)

3. **LOW PRIORITY (Future Enhancement):**
   - ARM performance optimization (Issue 5)
   - Advanced security scanning (Issue 6)

---

## 📝 **Code Review Checklist**

- [ ] All jobs have appropriate `needs` dependencies
- [ ] Manual dispatch uses `${{ github.event.inputs.machine }}`
- [ ] Artifact upload steps added to all build jobs
- [ ] Security scanning enhanced with Gitleaks
- [ ] Machine lists include all 19 configurations
- [ ] Timeouts set for long-running jobs
- [ ] YAML syntax validated
- [ ] Documentation updated

---

## 🔄 **Rollback Plan**

If corrections cause issues:
1. Revert to previous commit: `git revert HEAD`
2. Regenerate original workflow: `nix run .#generate-ci-workflow > .github/workflows/ci.yml`
3. Push hotfix: `git push origin main`

---

**Status:** PLAN COMPLETE  
**Next Action:** Implement corrections in ci.nix  
**Estimated Time:** 2-3 hours  
**Risk Level:** LOW (incremental improvements)