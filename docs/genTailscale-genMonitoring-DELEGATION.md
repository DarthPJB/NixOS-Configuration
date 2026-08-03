# genTailscale + genMonitoring — Delegation Plan

## Mission

Close the two remaining gaps in `mktopology.nix` so cortex-alpha (and all
hub machines) get full Tailscale VPN and Prometheus exporter configuration
from topology JSON. Both generators must produce output identical to what
`core-router-topology.nix` produced on `main`.

## Phase A: genTailscale.nix

### Step A1: Create genTailscale.nix

**Agent**: bellana-deepseek
**File**: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genTailscale.nix`

**Read these files first**:
- `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genForwarding.nix` (pattern to follow)
- `/speed-storage/bargman-tech/NixOS-Configuration/topology/cortex-alpha.json` (JSON schema — find `advertised_tailscale_routes`)
- Run `git show main:lib/topology/mkTailscaleConfig.nix` (old implementation for reference)

**Create this file**:
```nix
# [standard topology principle header — copy from genForwarding.nix]
{ lib }:
# genTailscale: topology -> config attrset
#
# Pure JSON-to-attrset function. NO BULLSHIT.
#
# Input: full topology JSON
# Output: { services.tailscale = { enable = true; useRoutingFeatures = "..."; extraSetFlags = [...]; }; }
#
# Reads topology.advertised_tailscale_routes (array of CIDR strings).
# If routes exist: enable tailscale as subnet router.
# If tailscale coordinate exists but no routes: enable tailscale without routing.
# If neither: return { }.
topology:
let
  inherit (builtins) filter head length concatStringsSep;
  inherit (lib) hasSuffix;

  coords = topology.coordinate or [ ];
  routes = topology.advertised_tailscale_routes or [ ];

  # Check if tailscale coordinate exists
  hasTailscaleCoord = builtins.any
    (c: (c.plane_name or "") == "tailscale-platonic")
    coords;

  # Build extraSetFlags with advertised routes
  routeFlags = if routes != [ ] then
    [ "--advertise-routes=${concatStringsSep "," routes}" ]
  else [ ];

in
if routes != [ ] then {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraSetFlags = routeFlags;
  };
}
else if hasTailscaleCoord then {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
  };
}
else { }
```

**Validate**:
```bash
nix eval --json --impure --expr '
  let
    lib = (import <nixpkgs> {}).lib;
    gen = import ./lib/topology/genTailscale.nix { inherit lib; };
    topology = builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json);
  in gen topology
' | jq .
```

Expected output:
```json
{
  "services": {
    "tailscale": {
      "enable": true,
      "extraSetFlags": [
        "--advertise-routes=10.88.128.88/32,10.88.127.107/32,10.88.128.248/32,10.88.128.247/32"
      ],
      "useRoutingFeatures": "server"
    }
  }
}
```

**Success criteria**: Output matches expected. No errors.

### Step A2: Wire genTailscale into mktopology.nix

**Agent**: bellana-deepseek
**File**: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/mktopology.nix`

**Changes**:
1. After line 56 (`genForwarding = ...`), add:
   ```nix
   genTailscale = import ./genTailscale.nix { inherit lib; };
   ```

2. In `mkMachineConfig` function, after the genForwarding block (around line 265), add:
   ```nix
   # ── Tailscale (conditional on advertised_tailscale_routes or tailscale coord) ─
   (genTailscale topology)
   ```

**Success criteria**: File compiles, no syntax errors.

### Step A3: Verify tailscale matches main

**Agent**: bellana-deepseek

**Run both and diff**:
```bash
# Main
nix eval --json --impure --expr \
  'let flake = builtins.getFlake (builtins.toString ./.); in { inherit (flake.nixosConfigurations.cortex-alpha.config.services.tailscale) enable useRoutingFeatures extraSetFlags; }' \
  > /tmp/ts-main.json

# Branch
nix eval --json --impure --expr \
  'let flake = builtins.getFlake (builtins.toString ./.); in { inherit (flake.nixosConfigurations.cortex-alpha.config.services.tailscale) enable useRoutingFeatures extraSetFlags; }' \
  > /tmp/ts-branch.json

diff /tmp/ts-main.json /tmp/ts-branch.json
```

**Success criteria**: No diff. Tailscale config is identical.

---

## Phase B: genMonitoring.nix

### Step B1: Create genMonitoring.nix

**Agent**: bellana-deepseek
**File**: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genMonitoring.nix`

**Read these files first**:
- `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genForwarding.nix` (pattern)
- `/speed-storage/bargman-tech/NixOS-Configuration/topology/cortex-alpha.json` (find `exporters` section)
- `/speed-storage/bargman-tech/NixOS-Configuration/topology/remote-worker.json` (has `nextcloud` and `nginx` exporters)
- Run `git show main:lib/topology/mkMonitoringSettings.nix` (old implementation)

**Create this file**:
```nix
# [standard topology principle header — copy from genForwarding.nix]
{ lib }:
# genMonitoring: topology -> config attrset
#
# Pure JSON-to-attrset function. NO BULLSHIT.
#
# Input: full topology JSON
# Output: { services.prometheus.exporters.<name> = { enable = true; ... }; }
#
# Reads topology.exporters attrset. For each key, generates a prometheus
# exporter config with enable = true and all key-value pairs from JSON.
# If no exporters: return { }.
topology:
let
  inherit (builtins) attrNames mapAttrs;
  exporters = topology.exporters or { };

  # Build a single exporter config from its JSON entry
  mkExporter = _name: cfg:
    { enable = true; } // cfg;

  # Build all exporter configs
  exporterConfigs = mapAttrs mkExporter exporters;

in
if exporters != { } then {
  services.prometheus.exporters = exporterConfigs;
}
else { }
```

**Validate**:
```bash
nix eval --json --impure --expr '
  let
    lib = (import <nixpkgs> {}).lib;
    gen = import ./lib/topology/genMonitoring.nix { inherit lib; };
    topology = builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json);
  in gen topology
' | jq .
```

Expected output:
```json
{
  "services": {
    "prometheus": {
      "exporters": {
        "dnsmasq": {
          "dnsmasqListenAddress": "10.88.128.1:53",
          "enable": true,
          "leasesPath": "/dev/null",
          "listenAddress": "10.88.127.1"
        }
      }
    }
  }
}
```

**Success criteria**: Output matches expected. `enable = true` is set. All JSON fields pass through.

### Step B2: Wire genMonitoring into mktopology.nix

**Agent**: bellana-deepseek
**File**: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/mktopology.nix`

**Changes**:
1. After the genTailscale import, add:
   ```nix
   genMonitoring = import ./genMonitoring.nix { inherit lib; };
   ```

2. In `mkMachineConfig` function, after the genTailscale block, add:
   ```nix
   # ── Prometheus exporters (conditional on topology.exporters) ─
   (if topology ? exporters then genMonitoring topology else { })
   ```

**Success criteria**: File compiles, no syntax errors.

### Step B3: Verify exporters match main

**Agent**: bellana-deepseek

**Run both and diff**:
```bash
# Main
nix eval --json --impure --expr \
  'let flake = builtins.getFlake (builtins.toString ./.); in { inherit (flake.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.dnsmasq) enable listenAddress port dnsmasqListenAddress leasesPath; }' \
  > /tmp/exp-main.json

# Branch
nix eval --json --impure --expr \
  'let flake = builtins.getFlake (builtins.toString ./.); in { inherit (flake.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.dnsmasq) enable listenAddress port dnsmasqListenAddress leasesPath; }' \
  > /tmp/exp-branch.json

diff /tmp/exp-main.json /tmp/exp-branch.json
```

**Success criteria**: No diff. Exporter config is identical.

---

## Phase C: Full Validation

### Step C1: Golden validation for all machines

**Agent**: bellana-deepseek

```bash
for m in $(ls machines/); do
  echo -n "$m: "
  nix run .#validate-goldens -- "$m" 2>&1 | tail -1
done
```

**Success criteria**: All 19 machines pass.

### Step C2: Regenerate affected goldens

**Agent**: bellana-deepseek

Any machine whose topology JSON has `advertised_tailscale_routes` or
`exporters` will fail golden validation and need regeneration:

```bash
for m in cortex-alpha remote-worker; do
  nix run .#dump-config -- "$m" 2>/dev/null | jq -S . > "goldens/$m.json"
done
```

Then re-run validation.

**Success criteria**: All 19 machines pass after golden regeneration.

### Step C3: Commit

**Agent**: bellana-deepseek

```bash
git add -A
git commit -m "feat: add genTailscale + genMonitoring — complete topology pipeline

mktopology was missing tailscale and monitoring generators from the
core-router-topology.nix migration. Cortex-alpha lost Tailscale VPN
and dnsmasq exporter configuration.

- Add lib/topology/genTailscale.nix (advertised_tailscale_routes → services.tailscale)
- Add lib/topology/genMonitoring.nix (exporters → services.prometheus.exporters)
- Wire both into mktopology.nix
- Regenerate affected goldens

All 19 goldens pass. Nix eval matches main for tailscale and exporters."
```

**Success criteria**: Commit succeeds. Clean git status.

---

## Verification Matrix

| Check | Command | Expected |
|-------|---------|----------|
| Tailscale enable | `nix eval ... services.tailscale.enable` | `true` |
| Tailscale routing | `nix eval ... services.tailscale.useRoutingFeatures` | `"server"` |
| Tailscale routes | `nix eval ... services.tailscale.extraSetFlags` | 4 CIDR routes |
| dnsmasq exporter | `nix eval ... exporters.dnsmasq.enable` | `true` |
| dnsmasq listen | `nix eval ... exporters.dnsmasq.listenAddress` | `"10.88.127.1"` |
| All goldens | `for m in ...; do validate-goldens; done` | 19/19 pass |
