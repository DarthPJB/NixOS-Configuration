# Topology-Driven Config Verification Plan

**Objective:** Verifycortex-alpha topology-driven configuration is 1:1 isomorphic with original stable baseline from 2026-04-22.

**Target:**cortex-alpha (core router / gateway)

---

## Phase 1: Baseline Establishment & Preconditions

### Step 1.1: Verify Golden File Integrity
```bash
# Validate golden file exists and is valid JSON
cat real-topology/golden/cortex-alpha.json | jq .
```

**Expected Evidence:**
- Valid JSON with all expected top-level keys:
  - `machine`: "cortex-alpha"
  - `networking.wireguard.interfaces.wireg0.peers`: 18 peers
  - `networking.firewall.interfaces`: 3 interfaces (enp2s0, enp3s0, wireg0)
  - `services.dnsmasq.settings.dhcp-host`: 11 DHCP reservations
  - `services.nginx.virtualHosts`: 9 virtualHosts
  - `networking.tailscale.advertisedRoutes`: 2 routes
  - `networking.nftables.enable`: true

**Pass Criteria:** JSON valid, all keys present

---

### Step 1.2: Verify Secret Files Exist
```bash
# Verify WireGuard public key files exist for all peers
ls -la secrets/public_keys/wireguard/wg_*

# Count must match peer count in golden (18)
ls secrets/public_keys/wireguard/ | wc -l
```

**Expected Evidence:**
- 18 public key files matching WireGuard peers in topology
- Files contain valid base64 keys (44 chars for Curve25519)

**Pass Criteria:** All 18 peer keys present and valid

---

### Step 1.3: Verify Baseline Revision Timestamp
```bash
# Find the baseline revision from 2026-04-22
git log --oneline --before="2026-04-23" | head -5
```

**Expected Evidence:**
- Commit history shows topology initialization commits on or before 2026-04-22
- Key baseline commits:
  - `fa33e166de08c263cf9833c7acfb3f62672e83eb`: initital pass at topology (2026-04-22)
  - `8dae2b92b8f0c9e3526b2425dbc7c2a16f1f9210`: much cleaner golden (2026-04-22)

**Pass Criteria:** Baseline commits identified and accessible

---

## Phase 2: Golden Test Validation

### Step 2.1: Run Network Golden Test
```bash
nix run .#check-network -- cortex-alpha
```

**Expected Evidence:**
```
--- real-topology/golden/cortex-alpha.json
+++ /tmp/current-network.json
[diff output or empty if match]
✓ Network config matches golden for cortex-alpha
```

**Pass Criteria:** Exit code 0 (diff empty or no changes)

---

### Step 2.2: Parse Golden Test Output - Identify Differences
```bash
# Capture detailed diff output
nix run .#generate-golden -- cortex-alpha | jq -S . > /tmp/current-golden.json
diff -u real-topology/golden/cortex-alpha.json /tmp/current-golden.json || true
```

**Expected Evidence:**
- Diff output showing ALL differences between current and golden
- Categorized by subsystem:
  - System packages (path differences acceptable)
  - Kernel sysctl (version-specific acceptable)
  - DHCP reservations (MAC format fixes)
  - Others (must be NONE for 1:1 isomorphism)

**Pass Criteria:** Only acceptable differences:
- System package store paths (different nixpkgs version)
- Kernel sysctl paths containing version numbers
- DHCP MAC format normalization (e.g., `52:54:00:e9-4a:af` → `52:54:00:e9:4a:af`)

---

## Phase 3: Subsystem Diff Validation

### Step 3.1: WireGuard Subsystem Diff
```bash
# Extract WireGuard config from both golden and current
jq -r '.["networking.wireguard.interfaces"]' real-topology/golden/cortex-alpha.json > /tmp/wg-golden.json
jq -r '.["networking.wireguard.interfaces"]' /tmp/current-golden.json > /tmp/wg-current.json
diff -u /tmp/wg-golden.json /tmp/wg-current.json
```

**Expected Evidence:**

*Golden File Structure:*
```json
{
  "wireg0": {
    "ips": ["10.88.127.1/32", "10.88.127.0/24"],
    "listenPort": 2108,
    "peers": [
      { "allowedIPs": ["10.88.127.88/32"], "publicKey": "<redacted>" },
      ... (18 peers total, ordered as in topology.wireguard.peers)
    ]
  }
}
```

**Pass Criteria:**
- `listenPort`: 2108 ✓
- `ips`: ["10.88.127.1/32", "10.88.127.0/24"] ✓
- Peer count: 18 ✓
- Peer order: MUST match topology.wireguard.peers order
- Peer publicKeys: redacted (ok for diff)
- Peer allowedIPs: each equals "${wireguardIp}/32" ✓

---

### Step 3.2: Firewall/nftables Subsystem Diff
```bash
# Extract firewall config from both
jq -r '.["networking.firewall"]' real-topology/golden/cortex-alpha.json > /tmp/fw-golden.json
jq -r '.["networking.firewall"]' /tmp/current-golden.json > /tmp/fw-current.json
diff -u /tmp/fw-golden.json /tmp/fw-current.json
```

**Expected Evidence:**

*Golden File Structure (must match topology exactly):*
```json
{
  "allowedTCPPorts": [22, 636, 1108],
  "allowedUDPPorts": [],
  "interfaces": {
    "enp2s0": {
      "allowedTCPPorts": [2208],
      "allowedUDPPorts": [443, 1108, 2108, 4549, 4175, 4179, 4171, 41641]
    },
    "enp3s0": {
      "allowedTCPPorts": [443, 2208],
      "allowedUDPPorts": [53, 67, 1108, 2108]
    },
    "wireg0": {
      "allowedTCPPorts": [443, 3100, 3101, 3102],
      "allowedUDPPorts": [1108]
    }
  }
}
```

**Pass Criteria:** 1:1 match with golden (no diff)

---

### Step 3.3: dnsmasq DHCP/DNS Subsystem Diff
```bash
# Extract dnsmasq config from both
jq -r '.["services.dnsmasq.settings"]' real-topology/golden/cortex-alpha.json > /tmp/dns-golden.json
jq -r '.["services.dnsmasq.settings"]' /tmp/current-golden.json > /tmp/dns-current.json
diff -u /tmp/dns-golden.json /tmp/dns-current.json
```

**Expected Evidence:**

*Golden File Structure:*
```json
{
  "dhcp-range": ["enp3s0,10.88.128.128,10.88.128.254,24h"],
  "dhcp-host": [
    "10:0b:a9:7e:cc:8c,10.88.128.20,terminal-zero,infinite",
    "18:26:49:c5:48:24,10.88.128.89,LINDACORE,infinite",
    ... (11 reservations, sorted alphabetically by MAC)
  ],
  "address": [
    "/git.johnbargman.net/10.88.128.1",
    "/code.johnbargman.net/10.88.128.1",
    ... (8 static DNS entries)
  ],
  "server": ["208.67.220.220", "208.67.222.222", "1.0.0.1", "8.8.8.8"],
  "interface": ["enp3s0"],
  "domain": ["cortex-alpha"],
  "domain-needed": [true],
  "bogus-priv": [true],
  "no-resolv": [true],
  "cache-size": [1000]
}
```

**Pass Criteria:**
- DHCP range: "enp3s0,10.88.128.128,10.88.128.254,24h" ✓
- DHCP reservations: 11 entries, sorted by MAC address ✓
- DHCP static entries: 8 entries, matching topology.dns.static ✓
- DNS servers: 4 entries matching topology.dns.servers ✓
- Interface: "enp3s0" matching topology.dns.interface ✓
- All other settings as specified above ✓

---

### Step 3.4: Nginx Vhosts/Listen/proxyPass Subsystem Diff
```bash
# Extract nginx config from both
jq -r '.["services.nginx.virtualHosts"]' real-topology/golden/cortex-alpha.json > /tmp/nginx-golden.json
jq -r '.["services.nginx.virtualHosts"]' /tmp/current-golden.json > /tmp/nginx-current.json
diff -u /tmp/nginx-golden.json /tmp/nginx-current.json
```

**Expected Evidence:**

*Golden File Structure:*
```json
{
  "ap.johnbargman.net": {
    "listenAddresses": ["10.88.128.1", "10.88.127.1"],
    "locations": {
      "~/": {
        "proxyPass": "http://10.88.128.2:80",
        "proxyWebsockets": true
      }
    }
  },
  "code.johnbargman.net": {
    "listenAddresses": ["10.88.128.1", "10.88.127.1"],
    "locations": {
      "~/": {
        "proxyPass": "http://10.88.127.3:80",
        "proxyWebsockets": true
      }
    }
  },
  "git.johnbargman.net": { ... },
  "grafana.johnbargman.net": { ... },
  "prometheus.johnbargman.net": { ... },
  "print-controller.johnbargman.net": { ... },
  "johnbargman.net": { "enableACME": true, ... },
  "cortex-alpha.johnbargman.net": { ... }
}
```

**Pass Criteria:**
- VirtualHost count: 9 vhosts ✓
- Listen addresses: MUST match topology.nginx.listenAddresses (["10.88.128.1", "10.88.127.1"]) ✓
- proxyPass backends: MUST match topology.nginx.proxies exactly ✓
- All proxyWebsockets: true ✓
- ACME configuration: johnbargman.net wildcard ✓

---

### Step 3.5: Tailscale Routes Subsystem Diff
```bash
# Extract Tailscale config from both
jq -r '.["networking.tailscale.advertisedRoutes"]' real-topology/golden/cortex-alpha.json > /tmp/ts-golden.json
jq -r '.["networking.tailscale.advertisedRoutes"]' /tmp/current-golden.json > /tmp/ts-current.json
diff -u /tmp/ts-golden.json /tmp/ts-current.json

# Also check services.tailscale config
jq -r '.["services.tailscale"]' real-topology/golden/cortex-alpha.json > /tmp/ts-svc-golden.json
jq -r '.["services.tailscale"]' /tmp/current-golden.json > /tmp/ts-svc-current.json
diff -u /tmp/ts-svc-golden.json /tmp/ts-svc-current.json
```

**Expected Evidence:**

*Golden File Structure:*
```json
{
  "advertisedRoutes": ["10.88.128.88/32", "10.88.128.248/32"],
  "services.tailscale": {
    "enable": true,
    "useRoutingFeatures": "server",
    "extraSetFlags": ["--advertise-routes=10.88.128.88/32,10.88.128.248/32"]
  }
}
```

**Pass Criteria:**
- subnetRouter: true (from topology.tailscale.subnetRouter) ✓
- advertisedRoutes: MUST exactly match topology.tailscale.advertisedRoutes ✓
- extraSetFlags: derived from advertisedRoutes with --advertise-routes= prefix ✓

---

## Phase 4: Detailed Diff Analysis & Regression Check

### Step 4.1: Compare Against Historical Baseline (2026-04-22)
```bash
# Create worktree for baseline revision
git worktree add /tmp/nixos-baseline fa33e166de08c263cf9833c7acfb3f62672e83eb

# Generate golden from baseline
cd /tmp/nixos-baseline && nix eval --json --impure --expr '
  let
    flake = builtins.getFlake (builtins.toString ./);
    lib = (import <nixpkgs> {}).lib;
    topology = import ./real-topology/default.nix { inherit lib; self = flake; };
  in
  topology.generateGolden "cortex-alpha"
' | jq -S . > /tmp/baseline-golden.json

# Compare with current golden
diff -u real-topology/golden/cortex-alpha.json /tmp/baseline-golden.json

# Cleanup
git worktree remove /tmp/nixos-baseline --force
```

**Expected Evidence:**
- Should show NO differences if baseline is correct
- If differences exist, document and categorize:
  - Expected: nixpkgs version differences
  - Unexpected: topology data changes (FAIL)

**Pass Criteria:** No unexpected differences

---

### Step 4.2: Full Config Serialization Comparison
```bash
# Dump full config for comparison with any revision
nix run .#dump-config -- cortex-alpha > /tmp/full-config.json

# Compare key networking sections
jq '.networking | keys' /tmp/full-config.json
jq '.services | keys' /tmp/full-config.json
```

**Expected Evidence:**
- All network subsystems present and configured
- All services: dnsmasq, nginx, tailscale, prometheus exporters

**Pass Criteria:** All expected subsystems configured

---

## Phase 5: Go/No-Go Decision

### Step 5.1: Compile Verification Results
```bash
# Generate verification summary
cat > /tmp/verification-summary.md << 'EOF'
# cortex-alpha Topology Verification Summary

## Phase Results

### Phase 1: Baseline Establishment
- [ ] Step 1.1: Golden file integrity - PASS/FAIL
- [ ] Step 1.2: Secret files exist - PASS/FAIL  
- [ ] Step 1.3: Baseline revision - PASS/FAIL

### Phase 2: Golden Test
- [ ] Step 2.1: Golden test passes - PASS/FAIL
- [ ] Step 2.2: Diff analysis - PASS/FAIL

### Phase 3: Subsystem Diffs
- [ ] Step 3.1: WireGuard - PASS/FAIL
- [ ] Step 3.2: Firewall/nftables - PASS/FAIL
- [ ] Step 3.3: dnsmasq - PASS/FAIL
- [ ] Step 3.4: Nginx - PASS/FAIL
- [ ] Step 3.5: Tailscale - PASS/FAIL

### Phase 4: Regression Check
- [ ] Step 4.1: Historical baseline - PASS/FAIL
- [ ] Step 4.2: Full config - PASS/FAIL

## Overall Assessment

### Go Criteria (ALL must pass):
1. Golden test EXACT match (only acceptable diffs)
2. WireGuard: 18 peers, correct order, correct IPs
3. Firewall: 3 interfaces, all ports match topology
4. dnsmasq: 11 DHCP reservations, 8 DNS entries
5. Nginx: 9 vhosts, correct proxyPass backends
6. Tailscale: 2 advertised routes

### No-Go Criteria (ANY fails = NO DEPLOY):
1. Golden test fails withunexpected differences
2. WireGuard peer count/order mismatch
3. Missing firewall ports or interfaces
4. DHCP/DNS configuration drift
5. Nginx proxyPass backend mismatch
6. Tailscale route mismatch
EOF
view /tmp/verification-summary.md
```

---

### Step 5.2: Execute Go/No-Go Decision
```bash
# Final verification check - MUST be 1:1 match for deploy
echo "=== FINAL GO/NO-GO CHECK ==="
echo ""
echo "Only acceptable differences:"
echo "  1. System package store paths (different nixpkgs)"
echo "  2. Kernel sysctl paths containing version numbers"
echo "  3. DHCP MAC format normalization (52:54:00:e9-4a:af -> 52:54:00:e9:4a:af)"
echo ""
echo "Any OTHER differences = MISSION CRITICAL - DO NOT DEPLOY"
echo ""
echo "To deploy after verification:"
echo "  1. Update golden if intentional: nix run .#generate-golden -- cortex-alpha > real-topology/golden/cortex-alpha.json"
echo "  2. Deploy: nix run .#cortex-alpha -- switch"
```

---

## Verification Commands Quick Reference

| Step | Command | Pass Criteria |
|------|---------|--------------|
| Golden test | `nix run .#check-network -- cortex-alpha` | Exit 0 |
| Generate | `nix run .#generate-golden -- cortex-alpha \| jq -S . > /tmp/current.json` | Valid JSON |
| Extract WG | `jq '.["networking.wireguard.interfaces"]' /tmp/current.json` | 18 peers |
| Extract FW | `jq '.["networking.firewall"]' /tmp/current.json` | 3 ifaces |
| Extract DNS| `jq '.["services.dnsmasq.settings"]' /tmp/current.json` | 11 DHCP |
| Extract NGX| `jq '.["services.nginx.virtualHosts"]' /tmp/current.json` | 9 vhosts |
| Extract TS | `jq '.["networking.tailscale.advertisedRoutes"]' /tmp/current.json` | 2 routes |

---

## Expected Artifacts (per run)

Each subsystem verification produces:
1. JSON extract files in `/tmp/`
2. Diff output (empty = pass)
3. Count verification (exact numbers)

**CRITICAL:** Store all diffs and comparison outputs for audit trail before any deployment.