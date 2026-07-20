# PONR-0.3: Competing Sources — File:Line Anchors

**Date:** 2026-07-20
**Purpose:** Document every file:line range that produces managed keys that will compete with topology-derive after wiring. These must be commented out (preservingly) in PONR-2.

---

## 1. cortex-alpha

### 1a. `machines/cortex-alpha/default.nix` — dnsmasq exporter (lines 56–62)

```nix
# File: machines/cortex-alpha/default.nix
# Lines: 56–62
services.prometheus.exporters.dnsmasq = {
  enable = true;
  listenAddress = "10.88.127.1";
  port = 3101;
  leasesPath = "/dev/null";
  dnsmasqListenAddress = "10.88.128.1:53";
};
```

**Managed key:** `services.prometheus.exporters.dnsmasq`
**Action:** Comment block. Topology-derive will set this from `cortex-alpha.json` exporters.
**Note:** Topology-derive currently doesn't set `leasesPath` or `dnsmasqListenAddress` (MODULE_BUG). These are exporter-specific options that may need to remain or be added to JSON schema.
**Sticky comment:**
```nix
# TOPOLOGY-DERIVED: see topology/cortex-alpha.json exporters.dnsmasq
```

### 1b. `topology/cortex-alpha.nix` — nginx block (lines 504–566)

```nix
# File: topology/cortex-alpha.nix
# Lines: 504–566
nginx = {
  acmeHost = "johnbargman.net";
  listenAddresses = [ "10.88.128.1" "10.88.127.1" "82.5.173.252" ];
  baseVhosts = { ... };
  proxies = { ... };
};
```

**Managed key:** `services.nginx.virtualHosts` (indirectly, via core-router-topology.nix genNginx path)
**Action:** Comment block. Topology-derive reads from `cortex-alpha.json` vhosts instead.
**Note:** This is the *source data* for the current nginx generation. The .nix file is read by `core-router-topology.nix` line 29 (`import ../topology/${hostname}.nix`). With topology-derive wired, the JSON file replaces this.
**Sticky comment:**
```nix
# TOPOLOGY-DERIVED: see topology/cortex-alpha.json vhosts
```

### 1c. `modules/core-router-topology.nix` — nginx generation path (lines 45, 50, 160–164)

```nix
# File: modules/core-router-topology.nix
# Line 45:  nginxSettings = (import ../lib/topology/mkNginxSettings.nix { inherit lib; }) perMachineTopology;
# Line 50:  nginxConfig = (import ../lib/topology/genNginx.nix { inherit lib; }) nginxSettings hostname;
# Lines 160–164:
  (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? nginx && (machineTopology.nginx.proxies or { }) != { }) {
    services.nginx.enable = lib.mkOverride 100 true;
    services.nginx.virtualHosts = lib.mkOverride 100 nginxConfig.services.nginx.virtualHosts;
    users.users.nginx.extraGroups = [ "acme" ];
  })
```

**Managed key:** `services.nginx.enable`, `services.nginx.virtualHosts`
**Action:** Comment out lines 160–164 (the entire nginx config block). Leave the nginxSettings/nginxConfig computation at lines 45/50 in place if needed for transition, or comment those too.
**Note:** This uses `lib.mkOverride 100` which would OVERRIDE topology-derive's normal merge. Must be neutralized before wiring topology-derive.
**Critical:** Do NOT comment out the WireGuard/DNS/firewall/forwarding/Tailscale paths (lines 39–41, 53–55, 128–157) — those remain as-is.

### 1d. `machines/cortex-alpha/default.nix` — interface enp3s0 (lines 99–107)

```nix
# File: machines/cortex-alpha/default.nix
# Lines: 99–107
interfaces.enp3s0 = {
  useDHCP = lib.mkDefault false;
  ipv4.addresses = [{
    address = "10.88.128.1";
    prefixLength = 24;
  }];
};
```

**Managed key:** `networking.interfaces.enp3s0.ipv4.addresses`
**Action:** Comment block. Topology-derive will set the same address from JSON coordinate.
**Sticky comment:**
```nix
# TOPOLOGY-DERIVED: see topology/cortex-alpha.json coordinate
```

### 1e. `machines/cortex-alpha/default.nix` — interface enp2s0 (lines 109–111)

```nix
# File: machines/cortex-alpha/default.nix
# Lines: 109–111
interfaces.enp2s0 = {
  useDHCP = lib.mkDefault true;
};
```

**Managed key:** `networking.interfaces.enp2s0.useDHCP`
**Action:** Leave as-is. Topology-derive sets a static address for enp2s0 (82.5.173.252/24) which conflicts with DHCP usage. Either:
- Remove the DHCP config and accept the static address from topology, OR
- Keep DHCP and remove the enp2s0 coordinate from JSON
**Note:** This needs resolution — the WAN interface is currently DHCP but topology assigns a static IP.

---

## 2. remote-worker

### 2a. `machines/remote-worker/default.nix` — nginx (lines 43–86)

```nix
# File: machines/remote-worker/default.nix
# Lines: 43–86
services.nginx = {
  enable = true;
  statusPage = true;
  virtualHosts = {
    "default" = { default = true; locations."/" = { return = "444"; }; };
    "johnbargman.net" = { enableACME = true; ... };
    "johnbargman.com" = { enableACME = true; ... };
    "johnbargman.com-wg" = { serverName = "johnbargman.com"; ... };
  };
};
```

**Managed key:** `services.nginx.enable`, `services.nginx.virtualHosts` (johnbargman.net, johnbargman.com, johnbargman.com-wg)
**Action:** Comment block for the entire nginx block. The `default` vhost will be replaced by topology-derive's `_` vhost.
**Note:** `statusPage = true` is a global nginx option — must be set elsewhere or accepted as loss. The vhosts `nextcloud.*`, `carmel-staging.*`, `csf*` are NOT in the nginx block here — they come from other modules and are OUT_OF_SCOPE.

### 2b. `machines/remote-worker/default.nix` — nginx exporter (lines 104–107)

```nix
# File: machines/remote-worker/default.nix
# Lines: 104–107
services.prometheus.exporters.nginx = {
  enable = true;
  port = 3105;
};
```

**Managed key:** `services.prometheus.exporters.nginx`
**Action:** Comment block. Topology-derive sets this from JSON (listenAddress from firstIP).

### 2c. `machines/remote-worker/default.nix` — nextcloud exporter (lines 109–116)

```nix
# File: machines/remote-worker/default.nix
# Lines: 109–116
services.prometheus.exporters.nextcloud = {
  enable = true;
  port = 3106;
  url = "https://nextcloud.johnbargman.net";
  username = "admin";
  passwordFile = config.secrix.system.secrets.nextcloud_password_file.decrypted.path;
  user = "nextcloud";
};
```

**Managed key:** `services.prometheus.exporters.nextcloud`
**Action:** Comment block. Topology-derive sets basic shape (enable, port, listenAddress). Extra options (url, username, passwordFile, user) are exporter-specific and may need to be preserved or added to JSON.
**Sticky comment:**
```nix
# TOPOLOGY-DERIVED (basic): see topology/remote-worker.json exporters
# Exporter-specific options preserved:
#   url, username, passwordFile, user
```

### 2d. `machines/remote-worker/default.nix` — smartctl disable (line 90)

```nix
# File: machines/remote-worker/default.nix
# Line: 90
services.prometheus.exporters.smartctl.enable = lib.mkForce false;
```

**Managed key:** `services.prometheus.exporters.smartctl`
**Action:** If smartctl is REMOVED from remote-worker.json (JSON_DATA fix in PONR-1), this line can remain. If smartctl stays in JSON, this line must be commented to let topology-derive enable it.
**Preferred:** Remove smartctl from remote-worker.json (JSON_DATA fix). Then this line stays.

---

## 3. gaming-host-1

### 3a. `machines/gaming-host-1/default.nix` — nginx (lines 66–78)

```nix
# File: machines/gaming-host-1/default.nix
# Lines: 66–78
services.nginx = {
  enable = true;
  recommendedProxySettings = true;
  recommendedTlsSettings = true;
  virtualHosts."gaming-host-1.johnbargman.net" = {
    forceSSL = true;
    useACMEHost = "gaming-host-1.johnbargman.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
    };
  };
};
```

**Managed key:** `services.nginx.enable`, `services.nginx.virtualHosts."gaming-host-1.johnbargman.net"`
**Action:** Comment block. Topology-derive sets this from `gaming-host-1.json` vhosts.
**Note:** `recommendedProxySettings` and `recommendedTlsSettings` are global nginx options. These need to be preserved outside the commented block or set via another mechanism.
**Sticky comment:**
```nix
# TOPOLOGY-DERIVED: see topology/gaming-host-1.json vhosts
# Preserve: recommendedProxySettings, recommendedTlsSettings
```

---

## 4. display-1

### 4a. `machines/display-1/default.nix` — smartctl disable (line 138)

```nix
# File: machines/display-1/default.nix
# Line: 138
services.prometheus.exporters.smartctl.enable = lib.mkForce false;
```

**Managed key:** `services.prometheus.exporters.smartctl`
**Action:** If smartctl is REMOVED from display-1.json (JSON_DATA fix in PONR-1), this line stays. Remove the mkForce false by commenting if topology should handle it.
**Preferred:** Remove smartctl from display-1.json.

---

## 5. display-2

### 5a. `machines/display-2/default.nix` — smartctl disable (line 89)

```nix
# File: machines/display-2/default.nix
# Line: 89
services.prometheus.exporters.smartctl.enable = lib.mkForce false;
```

**Managed key:** `services.prometheus.exporters.smartctl`
**Action:** Same as display-1. Remove smartctl from display-2.json preferred.

---

## 6. print-controller

### 6a. `machines/print-controller/default.nix` — smartctl disable (line 42)

```nix
# File: machines/print-controller/default.nix
# Line: 42
services.prometheus.exporters.smartctl.enable = lib.mkForce false;
```

**Managed key:** `services.prometheus.exporters.smartctl`
**Action:** Same as display-1. Remove smartctl from print-controller.json preferred.

---

## 7. remote-builder

### 7a. `machines/remote-builder/default.nix` — smartctl disable (line 26)

```nix
# File: machines/remote-builder/default.nix
# Line: 26
services.prometheus.exporters.smartctl.enable = lib.mkForce false;
```

**Managed key:** `services.prometheus.exporters.smartctl`
**Action:** Same as display-1. Remove smartctl from remote-builder.json preferred.

---

## 8. Core Router Topology Module — nginx path

### 8a. `modules/core-router-topology.nix` — nginx config block (lines 160–164)

```nix
# File: modules/core-router-topology.nix
# Lines: 160-164
  (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? nginx && (machineTopology.nginx.proxies or { }) != { }) {
    services.nginx.enable = lib.mkOverride 100 true;
    services.nginx.virtualHosts = lib.mkOverride 100 nginxConfig.services.nginx.virtualHosts;
    users.users.nginx.extraGroups = [ "acme" ];
  })
```

**Managed key:** `services.nginx.enable`, `services.nginx.virtualHosts`
**Action:** Comment out this entire block (lines 160–165).
**Note:** Condition `machineTopology ? nginx` reads from `.nix files` (the old format). When topology-derive reads from `.json` files, this condition may or may not trigger. NEUTRALIZE regardless to prevent any residual competition.
**Preserve:** WireGuard lines 128–135, Tailscale 137–141, DNS 143–146, Firewall 148–151, Forwarding 153–157.

---

## 9. Core Router Topology Module — prometheus exporters path (lines 167–170)

```nix
# File: modules/core-router-topology.nix
# Lines: 167-170
  (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? monitoring) {
    services.prometheus.exporters = lib.mkOverride 100 (monitoringLib.mkMonitoringConfig { });
  })
```

**Managed key:** `services.prometheus.exporters`
**Action:** Comment out. Topology-derive sets exporters from JSON.
**Note:** The `monitoring` key in `.nix` files is the old format. JSON uses `exporters`.

---

## 10. Interface Address Collision Zones

### 10a. wireg0 — ALL client machines

All 13 WireGuard client machines use `enable-wg-topology.nix` which sets up `wireg0` including either interfaces or WireGuard config. Topology-derive from JSON will set `networking.interfaces.wireg0.ipv4.addresses`. These must not conflict.

**Action:** The `enable-wg-topology.nix` module sets `networking.wireguard.interfaces.wireg0.ips = [...]`. Topology-derive sets `networking.interfaces.wireg0.ipv4.addresses = [...]`. These are DIFFERENT NixOS options — they both contribute to the system's WireGuard interface config. No conflict if both set the same IP.

**Verify:** After wiring, ensure `check-network` passes. The golden test will catch any drift.

### 10b. wlan0 — print-controller

`topology/print-controller.json` has coordinate with `interface: "wlan0"` → derive sets `10.88.128.10/24` on wlan0. The hardware-configuration may also set wlan0 via DHCP.

**Action:** Check `machines/print-controller/hardware-configuration.nix` for wlan0 DHCP config. If present, either remove DHCP or remove the wlan0 coordinate from JSON.

---

## Action Checklist (PONR-2)

| # | File | Lines | Action | Status |
|---|------|-------|--------|--------|
| 1 | `machines/cortex-alpha/default.nix` | 56–62 | Comment dnsmasq exporter | PENDING |
| 2 | `topology/cortex-alpha.nix` | 504–566 | Comment nginx block | PENDING |
| 3 | `modules/core-router-topology.nix` | 160–164 | Comment nginx generation | PENDING |
| 4 | `modules/core-router-topology.nix` | 167–170 | Comment exporters generation | PENDING |
| 5 | `machines/cortex-alpha/default.nix` | 99–107 | Comment enp3s0 interface | PENDING |
| 6 | `machines/remote-worker/default.nix` | 43–86 | Comment nginx block | PENDING |
| 7 | `machines/remote-worker/default.nix` | 104–107 | Comment nginx exporter | PENDING |
| 8 | `machines/remote-worker/default.nix` | 109–116 | Comment nextcloud exporter | PENDING |
| 9 | `machines/gaming-host-1/default.nix` | 66–78 | Comment nginx block | PENDING |
| 10 | `machines/display-1/default.nix` | 138 | smartctl mkForce false | PENDING* |
| 11 | `machines/display-2/default.nix` | 89 | smartctl mkForce false | PENDING* |
| 12 | `machines/print-controller/default.nix` | 42 | smartctl mkForce false | PENDING* |
| 13 | `machines/remote-builder/default.nix` | 26 | smartctl mkForce false | PENDING* |
| 14 | `machines/cortex-alpha/default.nix` | 109–111 | enp2s0 DHCP config | PENDING** |

*\* = If smartctl removed from JSON, these stay; if not, comment them*
*\** = Needs resolution: static vs DHCP on WAN interface*
