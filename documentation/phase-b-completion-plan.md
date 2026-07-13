# Phase B: Complete Transformer Architecture — Execution Plan

> **Generated:** 2026-07-13
> **Branch:** overlord-II (v2-rc3)
> **Goal:** Wire WIP two-layer architecture into cortex-alpha, validate golden parity, add backup topology

---

## Current State Assessment

### Transformers (WIP) — All Implemented
| Transformer | Status | File |
|-------------|--------|------|
| `mkDnsSettings` | ✅ Implemented | `lib/topology/mkDnsSettings.nix` |
| `mkFirewallSettings` | ✅ Implemented | `lib/topology/mkFirewallSettings.nix` |
| `mkNginxSettings` | ✅ Implemented | `lib/topology/mkNginxSettings.nix` |
| `mkBackupSettings` | ✅ First-draft | `lib/topology/mkBackupSettings.nix` |

### Generators (WIP) — All Implemented
| Generator | Status | File |
|-----------|--------|------|
| `genDns` | ✅ Implemented | `lib/topology/genDns.nix` |
| `genFirewall` | ✅ Implemented | `lib/topology/genFirewall.nix` |
| `genNginx` | ✅ Implemented | `lib/topology/genNginx.nix` |
| `genBackup` | ❌ Not created | — |

### Integration Module — Implemented, Not Wired
| Module | Status | File |
|--------|--------|------|
| `core-router-topology.nix` | ✅ Implemented | `modules/core-router-topology.nix` |
| `enable-wg-topology.nix` | ✅ Deployed (13 machines) | `modules/enable-wg-topology.nix` |

### Backup Topology — Not in topology files
- `mkBackupSettings.nix` exists but has no backing data in `topology/shared.nix` or `topology/cortex-alpha.nix`
- No `genBackup.nix` generator exists

---

## Phase B Execution Steps

### Step 1: Validate core-router-topology.nix Output Parity

**Objective:** Confirm the WIP module produces byte-identical NixOS config to the production `core-router.nix` module.

**Method:**
1. Build cortex-alpha with production `core-router.nix` (current state)
2. Build cortex-alpha with WIP `core-router-topology.nix` (swap import)
3. Diff the serialized configs

**References:**
- Production: `modules/core-router.nix`
- WIP: `modules/core-router-topology.nix`
- Validation: `lib/topology/validate.nix`
- Golden: `goldens/cortex-alpha.json`

**Success Criteria:**
- Serialized config diff is empty (byte-identical)
- OR differences are documented and explained (e.g., new fields added by WIP)

**Prompt for bellana-deepseek:**
```
Validate that modules/core-router-topology.nix produces byte-identical NixOS
config to modules/core-router.nix for cortex-alpha.

1. Read both modules and compare their data flow
2. Run: nix eval --json .#nixosConfigurations.cortex-alpha.config.services.dnsmasq
3. Run: nix eval --json .#nixosConfigurations.cortex-alpha.config.networking.firewall
4. Run: nix eval --json .#nixosConfigurations.cortex-alpha.config.services.nginx
5. Document any differences

Files:
- /speed-storage/bargman-tech/NixOS-Configuration/modules/core-router.nix
- /speed-storage/bargman-tech/NixOS-Configuration/modules/core-router-topology.nix
- /speed-storage/bargman-tech/NixOS-Configuration/topology/cortex-alpha.nix
```

---

### Step 2: Wire core-router-topology.nix into cortex-alpha

**Objective:** Replace the production `core-router.nix` import with `core-router-topology.nix` in cortex-alpha's machine config.

**Prerequisites:** Step 1 passes (output parity confirmed)

**Method:**
1. Edit `machines/cortex-alpha/default.nix`
2. Replace `../../modules/core-router.nix` with `../../modules/core-router-topology.nix`
3. Build and validate

**References:**
- Machine config: `machines/cortex-alpha/default.nix`
- WIP module: `modules/core-router-topology.nix`

**Success Criteria:**
- cortex-alpha builds successfully
- No new warnings or errors
- Golden test passes: `nix run .#check-network -- cortex-alpha`

**Prompt for bellana-deepseek:**
```
Wire core-router-topology.nix into cortex-alpha by replacing the core-router.nix import.

1. Read /speed-storage/bargman-tech/NixOS-Configuration/machines/cortex-alpha/default.nix
2. Find the import of core-router.nix
3. Replace with core-router-topology.nix
4. Build: nix build .#nixosConfigurations.cortex-alpha.config.system.build.toplevel
5. Validate: nix run .#check-network -- cortex-alpha

IMPORTANT: Do NOT regenerate golden files. If golden test fails, report the diff.
```

---

### Step 3: Validate Golden Parity After Wiring

**Objective:** Confirm the golden test still passes after switching to the WIP module.

**Prerequisites:** Step 2 complete (core-router-topology.nix wired in)

**Method:**
1. Run `nix run .#check-network -- cortex-alpha`
2. If fails, diff the output against golden
3. Document any intentional differences

**References:**
- Golden: `goldens/cortex-alpha.json`
- Check script: `flake.nix` (check-network app)

**Success Criteria:**
- Golden test passes (byte-identical output)
- OR differences are documented as intentional WIP additions

**Prompt for bellana-deepseek:**
```
Validate golden parity for cortex-alpha after wiring core-router-topology.nix.

1. Run: nix run .#check-network -- cortex-alpha
2. If fails, capture the diff output
3. Analyze: are differences from the WIP module or from other changes?
4. Report findings

DO NOT regenerate golden files. Report only.
```

---

### Step 4: Create genBackup.nix Generator

**Objective:** Create the backup generator that produces `environment.rclone-target` config from `mkBackupSettings` output.

**Method:**
1. Read `lib/rclone-target.nix` (the NixOS module)
2. Read `lib/topology/mkBackupSettings.nix` (the transformer)
3. Create `lib/topology/genBackup.nix` that maps settings to module options

**References:**
- Module: `lib/rclone-target.nix`
- Transformer: `lib/topology/mkBackupSettings.nix`
- Example config: `snippets/gaming-host-1-daily-backup.nix`

**Success Criteria:**
- `genBackup.nix` created
- Takes settings from `mkBackupSettings` and produces valid `environment.rclone-target` config
- Follows same pattern as genDns/genFirewall/genNginx

**Prompt for bellana-deepseek:**
```
Create lib/topology/genBackup.nix — the backup generator.

1. Read /speed-storage/bargman-tech/NixOS-Configuration/lib/rclone-target.nix to understand the module options
2. Read /speed-storage/bargman-tech/NixOS-Configuration/lib/topology/mkBackupSettings.nix to understand the transformer output
3. Read /speed-storage/bargman-tech/NixOS-Configuration/snippets/gaming-host-1-daily-backup.nix for example usage
4. Create genBackup.nix that maps transformer output to module config
5. Follow the pattern of genDns.nix/genFirewall.nix/genNginx.nix

The generator signature should be:
  settings: hostname: <NixOS config>
```

---

### Step 5: Add Backup Topology to cortex-alpha.nix

**Objective:** Add backup topology data to cortex-alpha's per-machine topology file.

**Prerequisites:** Step 4 complete (genBackup.nix created)

**Method:**
1. Read existing backup config in `machines/LINDA/default.nix` (reference implementation)
2. Add `backup` section to `topology/cortex-alpha.nix`
3. Include backup topology as first-draft WIP

**References:**
- Topology file: `topology/cortex-alpha.nix`
- LINDA backup config: `machines/LINDA/default.nix` (rclone-target section)
- Backup transformer: `lib/topology/mkBackupSettings.nix`

**Success Criteria:**
- `backup` section added to `topology/cortex-alpha.nix`
- Data matches the shape expected by `mkBackupSettings.nix`
- At least one backup target defined (e.g., NixOS-Configuration repo)

**Prompt for bellana-deepseek:**
```
Add backup topology data to cortex-alpha.nix.

1. Read /speed-storage/bargman-tech/NixOS-Configuration/machines/LINDA/default.nix
   — find the environment.rclone-target section for reference
2. Read /speed-storage/bargman-tech/NixOS-Configuration/lib/topology/mkBackupSettings.nix
   — understand the expected topology shape
3. Read /speed-storage/bargman-tech/NixOS-Configuration/topology/cortex-alpha.nix
4. Add a backup section with at least one target (NixOS-Configuration repo sync)

Example shape:
  backup = {
    configFile = ../../secrets/rclone/rclone.conf;
    user = "John88";
    targets = {
      nixos-config = {
        filePath = "/speed-storage/bargman-tech/NixOS-Configuration";
        remoteName = "minio:bargman-tech";
        calendar = "*-*-* *:15:00";
        mode = "copy";
        bwlimit = "10M";
      };
    };
  };
```

---

### Step 6: Wire Backup into core-router-topology.nix

**Objective:** Add backup transformer + generator to the WIP module.

**Prerequisites:** Steps 4 and 5 complete

**Method:**
1. Add `mkBackupSettings` transformer call to `core-router-topology.nix`
2. Add `genBackup` generator call
3. Add backup config to the module output

**References:**
- Module: `modules/core-router-topology.nix`
- Transformer: `lib/topology/mkBackupSettings.nix`
- Generator: `lib/topology/genBackup.nix`

**Success Criteria:**
- Backup config produced by the WIP module
- No conflicts with existing backup config (if any)
- Golden test still passes (or diff is documented)

**Prompt for bellana-deepseek:**
```
Wire backup transformer and generator into core-router-topology.nix.

1. Read /speed-storage/bargman-tech/NixOS-Configuration/modules/core-router-topology.nix
2. Add mkBackupSettings transformer call (follow dnsSettings/firewallSettings pattern)
3. Add genBackup generator call (follow dnsConfig/firewallConfig pattern)
4. Add backup config to the module output
5. Build and validate

Follow the existing pattern for DNS/Firewall/Nginx.
```

---

### Step 7: Final Validation

**Objective:** Confirm all Phase B items are complete and working.

**Prerequisites:** All previous steps complete

**Method:**
1. Run golden test: `nix run .#check-network -- cortex-alpha`
2. Verify backup topology is present in config
3. Verify all transformers produce valid output
4. Document any remaining WIP items

**Success Criteria:**
- Golden test passes
- Backup topology in cortex-alpha.nix
- genBackup.nix created and wired
- core-router-topology.nix wired into cortex-alpha
- All transformers and generators validated

**Prompt for bellana-deepseek:**
```
Final Phase B validation.

1. Run: nix run .#check-network -- cortex-alpha
2. Verify backup config: nix eval --json .#nixosConfigurations.cortex-alpha.config.environment.rclone-target
3. Verify all transformers are called in core-router-topology.nix
4. Document any remaining WIP items
5. Report Phase B completion status
```

---

## Execution Order

```
Step 1 (Validate parity)
    ↓ tpol-minimax verification gate
Step 2 (Wire core-router-topology.nix)
    ↓ tpol-minimax verification gate
Step 3 (Validate golden parity)
    ↓ tpol-minimax verification gate
Step 4 (Create genBackup.nix)
    ↓ tpol-minimax verification gate
Step 5 (Add backup topology)
    ↓ tpol-minimax verification gate
Step 6 (Wire backup into module)
    ↓ tpol-minimax verification gate
Step 7 (Final validation)
    ↓ tpol-minimax sign-off
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Golden drift from WIP module | Medium | High | Validate parity BEFORE wiring; document any intentional diffs |
| Backup topology shape mismatch | Low | Medium | Follow mkBackupSettings.nix expected shape exactly |
| core-router-topology.nix has bugs | Low | High | Step 1 validates before any changes; can revert |
| nixpkgs update breaks transformers | Low | Medium | We just merged updated nixpkgs; test after merge |

## References

- AGENTS.md — Phase B specification
- `modules/core-router.nix` — Production module
- `modules/core-router-topology.nix` — WIP module
- `lib/topology/validate.nix` — Validation utilities
- `goldens/cortex-alpha.json` — Golden test reference
- `lib/rclone-target.nix` — Backup NixOS module
