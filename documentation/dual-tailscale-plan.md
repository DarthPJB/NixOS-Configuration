# Multi-Tailscale on NixOS — Implementation Plan

**Date:** 2026-06-16
**Status:** FUTURE — Not for deployment until explicitly requested
**Author:** Enterprise (autonomous planning)
**Context:** Prepared in advance of needing to connect to multiple external tailnets (chloe-kever, david-lyon, tank, etc.)

---

## 1. Problem Statement

Tailscale's daemon (`tailscaled`) was designed as a single instance per machine. There is no first-class support for joining multiple tailnets simultaneously. This creates a problem when a Platonic Systems machine needs to also participate on external tailnets — partner networks, collaborator tailnets, customer networks.

**Goal:** Run N Tailscale daemons side-by-side on NixOS — the existing primary instance continues unchanged, and zero or more secondary instances join separate tailnets. All managed declaratively via `nixos-rebuild`.

---

## 2. Current State

### 2.1 Existing Tailscale Module

**File:** `locale/tailscale.nix`

A shared module imported by 5 machines:
- `cortex-alpha` (hub)
- `LINDA`
- `alpha-two`
- `remote-worker`
- `terminal-zero`

The module:
- Enables `services.tailscale`
- Installs `pkgs.tailscale` to system packages
- Supports optional route advertisement via `networking.tailscale.advertisedRoutes`
- Uses NixOS's built-in Tailscale module (which manages the primary `tailscaled.service`)

### 2.2 Current DNS

Managed by `resolvconf` — Tailscale's `tailscaled` invokes `resolvconf` to push MagicDNS nameservers. Not immutable. No `chattr +i` protection.

### 2.3 Future Tailnets

Planned secondary tailnets (not yet deployed):
- **chloe-kever** — collaborator tailnet
- **david-lyon** — collaborator tailnet
- **tank** — external network

Each will require its own daemon instance with distinct state, socket, TUN device, and UDP port.

---

## 3. Design

### 3.1 Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│  NixOS Host                                                   │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ tailscaled   │  │ tailscaled-  │  │ tailscaled-  │  ...    │
│  │ (primary)    │  │ chloe        │  │ david        │        │
│  │ port 41641   │  │ port 41642   │  │ port 41643   │        │
│  │ tun: ts0     │  │ tun: ts1     │  │ tun: ts2     │        │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │
│         │                 │                 │                 │
│  ┌──────┴─────────────────┴─────────────────┴──────────┐     │
│  │  /etc/resolv.conf (IMMUTABLE)                       │     │
│  │  nameserver 1.1.1.1                                 │     │
│  │  nameserver 8.8.8.8                                 │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  tailscale-hosts.service + timer                    │     │
│  │  Syncs /etc/hosts from ALL tailnets (primary + N)   │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Immutable `/etc/resolv.conf`** | Tailscale ships its own `resolvconf` binary — `networking.resolvconf.enable = false` doesn't help. `chattr +i` is the only reliable lock. |
| **`--netfilter-mode=off` on secondaries** | Prevents iptables conflicts. The primary tailnet continues managing its own firewall rules via NixOS. |
| **`--accept-dns=false` on secondaries** | Defense-in-depth — even if `resolv.conf` lock fails, the daemon won't push DNS. |
| **Static DNS resolvers** | We lose MagicDNS for all tailnets. Acceptable if `.ts.net` resolution isn't needed. |
| **Hosts file sync via timer** | Restores bare-hostname SSH resolution that MagicDNS would have provided. |
| **Attrset-based config** | `networking.dual-tailscale.tailscales` is an attrset — each key becomes a secondary tailnet. Add a tailnet by adding an attrset entry. |
| **Auto-incrementing ports/TUNs** | Each secondary tailnet gets `41641 + N` for UDP and `tailscaleN` for TUN, avoiding manual coordination. |

### 3.3 What You Gain

- N tailnets active simultaneously
- `ping`, `ssh`, and internal service access on any network
- Internet works through the real ISP (DNS goes to public resolvers)
- `ssh user@hyperhyper` works (bare hostname via `/etc/hosts` sync)
- Disambiguate collisions: `ssh user@hyperhyper.platonic` vs `ssh user@hyperhyper.chloe`
- `nixos-rebuild` is the only management interface

### 3.4 What You Lose

- MagicDNS for `.ts.net` domains (all tailnets)
- Exit nodes / subnet routing / MSS clamping on secondary tailnets (`--netfilter-mode=off`)
- Basic peer-to-peer connectivity still works (the common case)

---

## 4. Module Design

### 4.1 Option Schema

**File:** `locale/dual-tailscale.nix` (new)

```nix
options.networking.dual-tailscale = {
  enable = lib.mkEnableOption "multi-tailscale secondary daemons";

  dnsServers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ "1.1.1.1" "8.8.8.8" ];
    description = "Static DNS nameservers for /etc/resolv.conf";
  };

  tailscales = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable this secondary tailnet";
        };
      };
    });
    default = {};
    example = {
      chloe = {};
      david = {};
      tank = {};
    };
    description = ''
      Attrset of secondary tailnets. Each key becomes:
        - systemd unit: tailscaled-<key>.service
        - state dir: /var/lib/tailscale-<key>/
        - socket: /run/tailscale-<key>/tailscaled.sock
        - CLI wrapper: tailscale-<key>
        - TUN device: tailscale<N> (auto-assigned)
        - UDP port: 41641 + N (auto-assigned)
    '';
  };
};
```

### 4.2 Usage Example

```nix
# machines/LINDA/default.nix
{
  imports = [
    ../../locale/tailscale.nix      # primary (existing)
    ../../locale/dual-tailscale.nix  # secondary support
  ];

  networking.dual-tailscale = {
    enable = true;
    dnsServers = [ "1.1.1.1" "8.8.8.8" ];
    tailscales = {
      chloe = {};    # tailscaled-chloe.service, port 41642, tun tailscale1
      david = {};    # tailscaled-david.service, port 41643, tun tailscale2
      tank = {};     # tailscaled-tank.service,  port 41644, tun tailscale3
    };
  };
}
```

Adding a new tailnet = adding one line. Removing = deleting one line. `nixos-rebuild` handles the rest.

### 4.3 Port/TUN Assignment

The module iterates over `cfg.tailscales` with `builtins.attrNames` (sorted alphabetically) and assigns:
- **TUN:** `tailscale${index + 1}` (primary uses `tailscale0`)
- **UDP port:** `41641 + index + 1` (primary uses `41641`)

This means tailnet names sort alphabetically for deterministic assignment:
- `chloe` → index 0 → `tailscale1`, port `41642`
- `david` → index 1 → `tailscale2`, port `41643`
- `tank` → index 2 → `tailscale3`, port `41644`

---

## 5. Implementation Phases

### Phase 1: Create the Module

**File:** `locale/dual-tailscale.nix`

Implement:
- [ ] `options.networking.dual-tailscale` with `tailscales` attrset
- [ ] `lock-resolv-conf.service` — writes static DNS, sets `chattr +i`
- [ ] `tailscaled-<NAME>.service` — one per secondary tailnet, generated via `mapAttrs`
- [ ] `tailscale-<NAME>` CLI wrapper — one per secondary tailnet
- [ ] UDP firewall rules — auto-generated from port assignments
- [ ] `tailscale-hosts.service` + `tailscale-hosts.timer` — syncs `/etc/hosts` from ALL daemons (primary + all secondaries)
- [ ] `preStop` hooks for clean `chattr -i` on shutdown

### Phase 2: Wire into Target Machine(s)

When ready to deploy, add to the target machine's config:

```nix
imports = [
  ../../locale/dual-tailscale.nix
];

networking.dual-tailscale = {
  enable = true;
  tailscales = {
    chloe = {};
    # david = {};  # add when needed
    # tank = {};   # add when needed
  };
};
```

### Phase 3: First-Boot Verification

After rebuild + reboot:

1. `cat /etc/resolv.conf` — shows static nameservers, no "Generated by resolvconf"
2. `lsattr /etc/resolv.conf` — shows `i` flag
3. `tailscale status` — primary tailnet peers listed
4. `sudo tailscale-chloe status` — secondary daemon running (not yet authenticated)
5. `sudo tailscale-chloe up --netfilter-mode=off --accept-dns=false` — authenticate
6. `systemctl status tailscale-hosts` — timer ran, hosts synced
7. `grep -A 50 TAILSCALE-HOSTS /etc/hosts` — peer entries from all tailnets
8. `ssh <peer-hostname>` — resolves via synced hosts

### Phase 4: Add More Tailnets

Each new tailnet is one line in the `tailscales` attrset:

```nix
tailscales = {
  chloe = {};    # already authenticated
  david = {};    # new — authenticate after rebuild
  tank = {};     # new — authenticate after rebuild
};
```

After rebuild: `sudo tailscale-david up --netfilter-mode=off --accept-dns=false`

---

## 6. Module Implementation Details

### 6.1 `lock-resolv-conf.service`

```nix
systemd.services.lock-resolv-conf = {
  description = "Write static DNS and lock /etc/resolv.conf";
  wantedBy = [ "multi-user.target" ];
  before = [ "tailscaled.service" ]
    ++ map (name: "tailscaled-${name}.service") (builtins.attrNames cfg.tailscales);
  after = [ "network-online.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = pkgs.writeShellScript "lock-resolv-conf" ''
      set -euo pipefail
      ${lib.getExe' pkgs.e2fsprogs "chattr"} -i /etc/resolv.conf 2>/dev/null || true
      cat > /etc/resolv.conf << 'RESOLV'
      ${lib.concatMapStringsSep "\n" (ns: "nameserver ${ns}") cfg.dnsServers}
      RESOLV
      ${lib.getExe' pkgs.e2fsprogs "chattr"} +i /etc/resolv.conf
    '';
    ExecStop = pkgs.writeShellScript "unlock-resolv-conf" ''
      ${lib.getExe' pkgs.e2fsprogs "chattr"} -i /etc/resolv.conf 2>/dev/null || true
    '';
  };
};
```

### 6.2 Per-Tailnet Daemon (generated via `mapAttrs`)

For each `name` in `cfg.tailscales`:

| Parameter | Value |
|-----------|-------|
| Unit name | `tailscaled-${name}.service` |
| `--state` | `/var/lib/tailscale-${name}/tailscaled.state` |
| `--socket` | `/run/tailscale-${name}/tailscaled.sock` |
| `--tun` | `tailscale${index + 1}` |
| `--port` | `41641 + index + 1` |
| `RuntimeDirectory` | `tailscale-${name}` (mode 0755) |
| `StateDirectory` | `tailscale-${name}` (mode 0700) |
| `Type` | `notify` |
| `Restart` | `on-failure` |
| Capabilities | `cap_net_admin cap_net_bind_service cap_net_raw` |
| `ExecStartPost` | `tailscale --socket=... set --accept-dns=false` |

### 6.3 Per-Tailnet CLI Wrapper

```nix
environment.systemPackages = map (name:
  pkgs.writeShellScriptBin "tailscale-${name}" ''
    exec ${lib.getExe pkgs.tailscale} \
      --socket /run/tailscale-${name}/tailscaled.sock "$@"
  ''
) (builtins.attrNames cfg.tailscales);
```

### 6.4 `tailscale-hosts.service` + Timer

Collects peers from ALL sockets (primary + all secondaries) and writes to `/etc/hosts`:

```nix
systemd.services.tailscale-hosts = {
  description = "Sync /etc/hosts from all Tailscale tailnets";
  after = [ "tailscaled.service" ]
    ++ map (name: "tailscaled-${name}.service") (builtins.attrNames cfg.tailscales)
    ++ [ "network-online.target" ];
  wants = [ "network-online.target" ];
  path = [ pkgs.tailscale pkgs.gawk pkgs.coreutils ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = pkgs.writeShellScript "tailscale-hosts" ''
      set -euo pipefail
      BEGIN="# BEGIN TAILSCALE-HOSTS"
      END="# END TAILSCALE-HOSTS"

      tmp=$(mktemp /etc/.tailscale-hosts.XXXXXX)
      trap 'rm -f /tmp/.tailscale-peers.*' EXIT

      # Collect peers from all tailnets
      peers_file=$(mktemp /tmp/.tailscale-peers.XXXXXX)

      # Primary tailnet
      if [ -S /var/run/tailscale/tailscaled.sock ]; then
        tailscale --socket=/var/run/tailscale/tailscaled.sock status 2>/dev/null | \
          awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {
            ip=$1; name=$2
            if (name != "") printf "%s\t%s %s.primary\n", ip, name, name
          }' >> "$peers_file"
      fi

      # Secondary tailnets
      ${lib.concatMapStringsSep "\n" (name: ''
        if [ -S /run/tailscale-${name}/tailscaled.sock ]; then
          tailscale --socket=/run/tailscale-${name}/tailscaled.sock status 2>/dev/null | \
            awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {
              ip=$1; name=$2
              if (name != "") printf "%s\t%s %s.${name}\n", ip, name, name
            }' >> "$peers_file"
        fi
      '') (builtins.attrNames cfg.tailscales)}

      # Strip existing marker block, append fresh peers
      sed "/$BEGIN/,/$END/d" /etc/hosts > "$tmp"
      echo "$BEGIN" >> "$tmp"
      cat "$peers_file" >> "$tmp"
      echo "$END" >> "$tmp"
      chmod 644 "$tmp"
      mv -f "$tmp" /etc/hosts
    '';
  };
};

systemd.timers.tailscale-hosts = {
  description = "Periodically sync Tailscale peers to /etc/hosts";
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnBootSec = "30s";
    OnUnitActiveSec = "10min";
    Unit = "tailscale-hosts.service";
  };
};
```

### 6.5 Firewall Rules

```nix
networking.firewall.allowedUDPPorts = lib.range 41642 (41641 + builtins.length (builtins.attrNames cfg.tailscales));
```

---

## 7. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `chattr +i` prevents NixOS from managing `/etc/resolv.conf` | DNS breaks if lock service fails | `preStop` unlocks; manual `chattr -i` recovery documented |
| Hostname collision between tailnets | SSH ambiguity | Timer script emits `<hostname>.<network>` form; bare name uses primary |
| Auth token expires on any tailnet | Connectivity loss | Re-auth via `tailscale-<NAME> up` |
| `resolvconf` binary from Tailscale conflicts | DNS overwrite | `chattr +i` prevents all writes regardless of source |
| Alphabetical ordering changes port assignment | Re-auth needed if tailnets reordered | Document: tailnet names determine port/TUN assignment |

---

## 8. Recovery Procedures

### If DNS breaks after rebuild:

```bash
sudo chattr -i /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
```

### If a secondary daemon fails to start:

```bash
sudo systemctl stop tailscaled-<NAME>
sudo nixos-rebuild switch --rollback
```

### Nuclear option — full rollback:

```bash
sudo chattr -i /etc/resolv.conf
sudo systemctl stop tailscaled-<NAME>
sudo nixos-rebuild switch --rollback
# Or boot previous generation from GRUB menu
```

---

## 9. Success Criteria

- [ ] Module evaluates clean with zero secondary tailnets (no-op when `tailscales = {}`)
- [ ] Module evaluates clean with N secondary tailnets
- [ ] `nixos-rebuild switch` builds clean on target machine
- [ ] After reboot: `/etc/resolv.conf` is immutable with static DNS
- [ ] `tailscale status` shows primary tailnet peers
- [ ] `tailscale-<NAME> status` shows each secondary tailnet's peers
- [ ] `/etc/hosts` contains synced peer entries from all tailnets
- [ ] `ssh <peer-hostname>` resolves and connects via any tailnet
- [ ] Internet connectivity works through real ISP
- [ ] No iptables conflicts between daemons

---

## 10. File Manifest

| File | Action | Purpose |
|------|--------|---------|
| `locale/dual-tailscale.nix` | Create (future) | Parameterizable multi-tailscale module |
| `machines/<hostname>/default.nix` | Modify (future) | Import and configure per-machine |
| `documentation/dual-tailscale-plan.md` | Exists | This planning document |

---

## 11. Authentication Workflow

Each secondary tailnet requires one-time authentication after first deploy:

```bash
# For each tailnet:
sudo tailscale-<NAME> up --netfilter-mode=off --accept-dns=false
# Open the auth URL in a browser
# Log in to the tailnet
# Auth state persists in /var/lib/tailscale-<NAME>/ across reboots
```

Auth keys (pre-generated, non-interactive) can be used if available:
```bash
sudo tailscale-<NAME> up --netfilter-mode=off --accept-dns=false --authkey=tskey-auth-...
```

---

*"My vision is fully augmented." — JC Denton*
*One daemon per tailnet. One module for all of them. Zero DNS drama.*
