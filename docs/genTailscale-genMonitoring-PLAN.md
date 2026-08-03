# genTailscale + genMonitoring Implementation Plan

## Problem Statement

`mktopology` is missing two generators that `core-router-topology.nix` provided.
Without these, cortex-alpha (and all hub machines) lose Tailscale VPN and
Prometheus exporter configuration on deployment.

## Architecture Constraint

Both generators MUST follow the topology generator principle:
- Pure JSON-to-attrset functions
- Read ONLY topology JSON
- No module system, no hostname, no legacy paths

## Phase A: genTailscale.nix

### Context

On `main`, `mkTailscaleConfig.nix` reads:
- `topology.tailscale.subnetRouter` → `useRoutingFeatures = "server"`
- `topology.tailscale.advertisedHosts` → host IPs as /32 routes
- `topology.tailscale.advertisedRoutes` → explicit CIDR routes
- `topology.lan.hosts` where `routing.tailscale = true` → host IPs as /32 routes

On the branch JSON, the equivalent data is:
- `topology.advertised_tailscale_routes` — array of CIDR strings
- `topology.coordinate` with `plane_name: "tailscale-platonic"` — confirms tailscale presence

The cortex-alpha topology JSON has:
```json
{
  "advertised_tailscale_routes": [
    "10.88.128.88/32",
    "10.88.127.107/32",
    "10.88.128.248/32",
    "10.88.128.247/32"
  ]
}
```

### Expected Output

```nix
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-routes=10.88.128.88/32,10.88.127.107/32,10.88.128.248/32,10.88.128.247/32" ];
  };
}
```

### Implementation Steps

**Step A1**: Create `lib/topology/genTailscale.nix`

File: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genTailscale.nix`

Requirements:
1. `{ lib }:` parameter, takes full topology JSON
2. Check for `topology.advertised_tailscale_routes` (non-empty array)
3. If routes exist: `enable = true`, `useRoutingFeatures = "server"`, `extraSetFlags` with comma-joined routes
4. If no routes but `plane_name: "tailscale-platonic"` exists in coordinates: `enable = true`, `useRoutingFeatures = "none"`
5. If neither: return `{ }`
6. Include standard topology principle header

Reference:
- `git show main:lib/topology/mkTailscaleConfig.nix` (old implementation)
- `topology/cortex-alpha.json` (JSON schema)
- `lib/topology/genForwarding.nix` (pattern)

**Step A2**: Wire into mktopology.nix

File: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/mktopology.nix`

1. Add import: `genTailscale = import ./genTailscale.nix { inherit lib; };`
2. Add to mkMachineConfig fold:
   ```nix
   # ── Tailscale (conditional on advertised_tailscale_routes or tailscale coord) ─
   (genTailscale topology)
   ```

**Step A3**: Validate

```bash
nix eval --json --impure --expr '
  let
    lib = (import <nixpkgs> {}).lib;
    gen = import ./lib/topology/genTailscale.nix { inherit lib; };
    topology = builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json);
  in gen topology
' | jq .
```

Expected: `services.tailscale.enable = true`, `useRoutingFeatures = "server"`, `extraSetFlags` populated.

Compare against main:
```bash
nix eval --json --impure --expr '
  let flake = builtins.getFlake (builtins.toString ./.);
  in { inherit (flake.nixosConfigurations.cortex-alpha.config.services.tailscale) enable useRoutingFeatures; }
'
```

---

## Phase B: genMonitoring.nix

### Context

On `main`, `mkMonitoringSettings.nix` reads `topology.exporters` and generates
`services.prometheus.exporters` config for each exporter type.

The cortex-alpha topology JSON has:
```json
{
  "exporters": {
    "dnsmasq": {
      "listenAddress": "10.88.127.1",
      "leasesPath": "/dev/null",
      "dnsmasqListenAddress": "10.88.128.1:53"
    }
  }
}
```

On main, the dnsmasq exporter evaluates to:
```nix
{
  services.prometheus.exporters.dnsmasq = {
    enable = true;
    listenAddress = "10.88.127.1";
    port = 3101;
    leasesPath = "/dev/null";
    dnsmasqListenAddress = "10.88.128.1:53";
  };
}
```

### Implementation Steps

**Step B1**: Create `lib/topology/genMonitoring.nix`

File: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genMonitoring.nix`

Requirements:
1. `{ lib }:` parameter, takes full topology JSON
2. Read `topology.exporters` attrset
3. For each key in exporters, generate `services.prometheus.exporters.<name>` config
4. Each exporter gets `enable = true` plus all key-value pairs from the JSON
5. If no exporters: return `{ }`
6. Include standard topology principle header

Exporter JSON schema (each entry):
```json
{
  "dnsmasq": {
    "listenAddress": "10.88.127.1",
    "leasesPath": "/dev/null",
    "dnsmasqListenAddress": "10.88.128.1:53"
  }
}
```

Output:
```nix
{
  services.prometheus.exporters.dnsmasq = {
    enable = true;
    listenAddress = "10.88.127.1";
    leasesPath = "/dev/null";
    dnsmasqListenAddress = "10.88.128.1:53";
  };
}
```

Note: The `port` field may need a default (3101 for dnsmasq). Check the
topology JSON — if `port` is present, use it; if absent, use the NixOS
module default for that exporter type.

Reference:
- `git show main:lib/topology/mkMonitoringSettings.nix` (old implementation)
- `topology/cortex-alpha.json` (exporters schema)
- `topology/remote-worker.json` (has nextcloud + nginx exporters)
- `lib/topology/genForwarding.nix` (pattern)

**Step B2**: Wire into mktopology.nix

File: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/mktopology.nix`

1. Add import: `genMonitoring = import ./genMonitoring.nix { inherit lib; };`
2. Add to mkMachineConfig fold:
   ```nix
   # ── Prometheus exporters (conditional on topology.exporters) ─
   (if topology ? exporters then genMonitoring topology else { })
   ```

**Step B3**: Validate

```bash
nix eval --json --impure --expr '
  let
    lib = (import <nixpkgs> {}).lib;
    gen = import ./lib/topology/genMonitoring.nix { inherit lib; };
    topology = builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json);
  in gen topology
' | jq .
```

Expected: `services.prometheus.exporters.dnsmasq.enable = true` with correct addresses.

Compare against main:
```bash
nix eval --json --impure --expr '
  let flake = builtins.getFlake (builtins.toString ./.);
  in { inherit (flake.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.dnsmasq) enable listenAddress port dnsmasqListenAddress leasesPath; }
'
```

---

## Phase C: Full Validation

**Step C1**: Nix eval comparison — tailscale

```bash
# Main
nix eval --json --impure --expr '...' --option builders '' > /tmp/ts-main.json
# Branch
nix eval --json --impure --expr '...' --option builders '' > /tmp/ts-branch.json
diff /tmp/ts-main.json /tmp/ts-branch.json
```

Must be identical for `services.tailscale`.

**Step C2**: Nix eval comparison — exporters

Compare `services.prometheus.exporters` between main and branch for cortex-alpha.
Must be identical.

**Step C3**: Full golden validation

```bash
for m in $(ls machines/); do
  echo -n "$m: "
  nix run .#validate-goldens -- "$m" 2>&1 | tail -1
done
```

All 19 machines must pass.

**Step C4**: Regenerate affected goldens

Any machine whose topology JSON has `advertised_tailscale_routes` or `exporters`
will need golden regeneration.

**Step C5**: Commit

```
feat: add genTailscale.nix + genMonitoring.nix — restore full topology pipeline

mktopology was missing tailscale and monitoring generators. Cortex-alpha
lost Tailscale VPN and dnsmasq exporter configuration.

- Add lib/topology/genTailscale.nix (advertised_tailscale_routes → services.tailscale)
- Add lib/topology/genMonitoring.nix (exporters → services.prometheus.exporters)
- Wire both into mktopology.nix
- Regenerate affected goldens
```

---

## Verification Criteria

1. `services.tailscale.enable = true` on cortex-alpha (matches main)
2. `services.tailscale.useRoutingFeatures = "server"` (matches main)
3. `services.tailscale.extraSetFlags` contains advertised routes (matches main)
4. `services.prometheus.exporters.dnsmasq.enable = true` (matches main)
5. `services.prometheus.exporters.dnsmasq` config matches main exactly
6. All 19 goldens pass
7. Nix eval diff between main and branch shows no unexpected differences
