# Declarative DNS Management Plan

**Date:** 2026-06-12
**Status:** Proposed
**Author:** System Architecture

## Problem Statement

DNS records for `johnbargman.net` are managed across multiple mechanisms with no central coordination:

1. **No single source of truth** — DNS records are scattered across machine configs, manual Gandi console entries, and third-party services
2. **No audit trail** — changes are made via API calls and manual edits, not version-controlled config
3. **Drift risk** — manual DNS changes outside Nix are invisible to the system
4. **No protection against accidental deletion** — a naive sync could wipe Google Mail MX records or other third-party-managed entries
5. **Duplication** — each machine independently manages its own record with identical boilerplate

## Current State

### Three Categories of DNS Records

The zone `johnbargman.net` contains three distinct categories of records that must be handled differently:

#### Category 1: Static Records (Declarative)
Records for machines with fixed IPs that we control entirely.
- Example: WireGuard endpoints, internal services
- Management: Should be declared in Nix, pushed by `dns-sync`

#### Category 2: Dynamic Records (Per-Machine Timers)
Records for machines with changing public IPs (laptops, DHCP hosts).
- Example: `gaming-host-1.johnbargman.net` (public IP changes)
- Management: `dynamic_domain_gandi.nix` — per-machine systemd timer updates A record via Gandi LiveDNS API
- **This mechanism is intentional and must be preserved.**

#### Category 3: Preserved Records (Third-Party Managed)
Records managed by external services that we must NOT touch.
- Example: Google Mail MX records, SPF/DKIM for email, third-party CDN CNAMEs
- Management: Whitelist — `dns-sync` must never delete or modify these

### Current Mechanisms

**`services/dynamic_domain_gandi.nix`** — Dynamic DNS for machines with changing IPs:
- Runs a systemd timer every 60 minutes
- Fetches the machine's public IP via `ifconfig.me`
- Updates a single A record via Gandi LiveDNS API
- Uses `gandi_api_barg_net_token` secret
- **Stays as-is** — this is the correct pattern for dynamic hosts

**`services/acme_server.nix`** — TLS certificate provisioning:
- Uses Gandi DNS-01 challenge for ACME certificates
- Uses `gandi_dns01_token` secret
- Imported with `fqdn` parameter (e.g., `monmap.johnbargman.net`)

### Secrets Inventory

| Secret | File | Purpose |
|--------|------|---------|
| `gandi_api_barg_net_token` | `secrets/gandi_api_barg_net_token` | Gandi LiveDNS API (dynamic updates) |
| `gandi_dns01_token` | `secrets/gandi_dns01_token` | Gandi DNS-01 ACME challenge |
| `gandi_api_2025_08_23` | `secrets/gandi_api_2025_08_23` | Older Gandi API token (legacy?) |

### Existing DNS Records (Inferred)

| FQDN | Type | Category | Source |
|------|------|----------|--------|
| `gaming-host-1.johnbargman.net` | A | Dynamic | dynamic_domain_gandi.nix |
| `cortex-alpha.johnbargman.net` | A | Dynamic | dynamic_domain_gandi.nix |
| `monmap.johnbargman.net` | A/CNAME | Static | To be declared |
| Google Mail MX records | MX | Preserved | Google (manual) |
| SPF/DKIM records | TXT | Preserved | Google (manual) |

## Reference Implementation: infrastructure-2's cf-dns

### Architecture

The Platonic Systems infrastructure uses **octodns** (Python) with a **Cloudflare** provider:

```
systems/acropolis/default.nix    ─┐
systems/hyperhyper/default.nix   ─┤── octodns.zones.<zone>.records
systems/springboard/default.nix  ─┘
         │
         ▼
modules/octodns.nix              ─── NixOS option type definitions
         │
         ▼
flake.nix (cf-dns app)           ─── Collects all configs → YAML → octodns-sync
         │
         ▼
octodns-sync --force             ─── Pushes to Cloudflare
```

### Key Design Patterns

1. **Per-system declarations**: Each system declares its own DNS records
2. **Module type system**: Typed options for records (type, name, value, ttl, priority)
3. **Flake-level aggregation**: Collects all configs, merges, generates YAML, runs sync
4. **Secret management**: API token encrypted with `rage`, decrypted at runtime
5. **Integration with deploy**: `cf-dns` runs as part of `deploy-infra` before machine deployments

### Limitations of octodns Approach

octodns is designed for full zone management — it wants to own the entire zone. This is dangerous when:
- Third parties manage some records (Google Mail)
- Dynamic DNS timers update records independently
- We only want to manage a subset of records

**Our design must handle partial zone management.**

## Proposed Architecture

### Design Principles

1. **Topology is the source of truth** for machine IPs
2. **Services declare their own records** — nginx, squaremap, etc. declare DNS needs
3. **`dynamic_domain_gandi.nix` stays** — it handles machines with changing IPs
4. **Whitelist protects third-party records** — `dns-sync` never touches preserved records
5. **Single `nix run .#dns-sync` command** — pushes managed records to Gandi
6. **Gandi-native** — use Gandi LiveDNS API directly (not octodns/Cloudflare)
7. **Additive only by default** — `dns-sync` creates/updates records, never deletes unless explicitly told to

### Record Categories in Nix

```nix
dns.zones."johnbargman.net" = {
  # Records we manage declaratively
  records = {
    "monmap" = { type = "A"; value = "65.108.141.32"; };
    "monmap" = { type = "CNAME"; value = "gaming-host-1.johnbargman.net."; };
  };

  # Records managed by dynamic_domain_gandi.nix (informational, not synced)
  dynamicRecords = [
    "gaming-host-1"
    "cortex-alpha"
  ];

  # Records managed by third parties (NEVER touch these)
  preservedRecords = {
    # Google Mail
    "" = { type = "MX"; };  # root domain MX
    "google._domainkey" = { type = "TXT"; };
    "_dmarc" = { type = "TXT"; };
    # SPF at root
    "" = { type = "TXT"; };  # may conflict with our TXT — need careful handling
  };
};
```

### Module Definition

**`modules/dns-zones.nix`** — NixOS option type definitions:

```nix
{ config, lib, ... }:
{
  options.dns = {
    zones = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          # Records we manage and will push to Gandi
          records = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                type = lib.mkOption {
                  type = lib.types.enum [ "A" "AAAA" "CNAME" "MX" "TXT" "SRV" "NS" "CAA" ];
                  default = "A";
                };
                value = lib.mkOption {
                  type = lib.types.oneOf [ lib.types.str (lib.types.listOf lib.types.str) ];
                };
                ttl = lib.mkOption {
                  type = lib.types.int;
                  default = 300;
                };
              };
            });
            default = { };
            description = "DNS records managed by this configuration. Created/updated by dns-sync.";
          };

          # Record names managed by dynamic_domain_gandi.nix
          # dns-sync will NOT touch these (neither create nor delete)
          dynamicRecordNames = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Subdomain names managed by dynamic DNS timers. dns-sync will skip these.";
          };

          # Record names managed by third parties
          # dns-sync will NEVER touch these under any circumstances
          preservedRecordNames = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Subdomain names managed by third parties (e.g., Google Mail). dns-sync will never modify or delete these.";
          };
        };
      }));
      default = { };
      description = "DNS zone declarations. Each zone defines managed records, dynamic records, and preserved records.";
    };
  };
}
```

### Topology Integration

**`lib/dns/from-topology.nix`** — Generates DNS records from topology:

```nix
{ topology, domain }:
let
  # For each machine with a static public IP, create an A record
  # Machines with dynamic IPs are handled by dynamic_domain_gandi.nix
  mkRecords = name: cfg:
    let
      # Only create records for machines with static uplink IPs
      staticIp = cfg.uplink or null;
    in
    if staticIp != null then
      { "${name}" = { type = "A"; value = builtins.head (builtins.attrNames staticIp); }; }
    else
      { };
in
{
  "${domain}" = {
    records = builtins.foldl' (a: name: a // mkRecords name topology.${name}) {} (builtins.attrNames topology);
    # Machines with dynamic IPs — skip these in dns-sync
    dynamicRecordNames = builtins.filter (name:
      topology.${name} ? uplink == false
    ) (builtins.attrNames topology);
  };
}
```

### Service Integration

Services declare their own DNS records:

```nix
# In machines/gaming-host-1/default.nix:
dns.zones."johnbargman.net".records = {
  "monmap" = { type = "CNAME"; value = "gaming-host-1.johnbargman.net."; };
};
```

### Flake App

**`flake.nix`** — `dns-sync` app:

The sync logic must be **additive by default** with explicit delete opt-in:

```
dns-sync behavior:
  1. Fetch current records from Gandi LiveDNS API
  2. For each record in our config:
     - If it doesn't exist on Gandi → CREATE
     - If it exists but differs → UPDATE
     - If it exists and matches → SKIP
  3. For each record on Gandi that is NOT in our config:
     - If it's in dynamicRecordNames → SKIP (managed by timer)
     - If it's in preservedRecordNames → SKIP (managed by third party)
     - If it's in the whitelist → SKIP (manually excluded)
     - Otherwise → LOG WARNING (potential drift, but do NOT delete)
  4. Only delete if --delete flag is passed (interactive confirmation required)
```

```nix
apps.x86_64-linux.dns-sync = {
  type = "app";
  program = let
    # Collect all dns.zones from all nixosConfigurations
    allZones = lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList (_: v: v.config.dns.zones or { }) self.nixosConfigurations
    );
    
    # Generate sync script
    syncScript = pkgs.writeShellApplication {
      name = "dns-sync";
      runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils ];
      text = ''
        API_KEY_FILE="''${1:?Usage: dns-sync <gandi-api-key-file> [--delete]}"
        DELETE_MODE="''${2:-}"
        
        API_KEY=$(cat "$API_KEY_FILE")
        GANDI_API="https://api.gandi.net/v5/livedns"
        
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (zone: zoneCfg:
          let
            zoneName = lib.removeSuffix "." zone;
            managedRecords = zoneCfg.records or { };
            dynamicNames = zoneCfg.dynamicRecordNames or [ ];
            preservedNames = zoneCfg.preservedRecordNames or [ ];
          in
          ''
            echo "=== Syncing zone: ${zoneName} ==="
            
            # Fetch current records from Gandi
            CURRENT=$(curl -s -H "Authorization: Bearer $API_KEY" \
              "$GANDI_API/domains/${zoneName}/records")
            
            # Process each managed record
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: record:
              let
                fqdn = if name == "" then zoneName else "${name}.${zoneName}";
              in
              ''
                echo "  Checking: ${fqdn} (${record.type})"
                # PUT creates or updates — idempotent
                curl -s -X PUT -H "Authorization: Bearer $API_KEY" \
                  -H "Content-Type: application/json" \
                  -d '{"rrset_name": "${name}", "rrset_type": "${record.type}", "rrset_ttl": ${toString record.ttl}, "rrset_values": ${if builtins.isList record.value then builtins.toJSON record.value else ''["${record.value}"]''}}' \
                  "$GANDI_API/domains/${zoneName}/records/${name}/${record.type}"
                echo "  ✓ ${fqdn}"
              ''
            ) managedRecords)}
            
            # Warn about unmanaged records (but don't delete)
            echo "  Checking for drift..."
            # Dynamic and preserved records are excluded from drift detection
            echo "  Dynamic records (skipped): ${lib.concatStringsSep ", " dynamicNames}"
            echo "  Preserved records (skipped): ${lib.concatStringsSep ", " preservedNames}"
          ''
        ) allZones)}
      '';
    };
  in "${lib.getExe syncScript}";
};
```

### Whitelist Mechanism

For records that don't fit neatly into "dynamic" or "preserved" categories:

```nix
dns.zones."johnbargman.net" = {
  # Explicit whitelist of record name+type pairs to never touch
  whitelist = [
    { name = ""; type = "MX"; }           # Google Mail MX
    { name = ""; type = "TXT"; }          # SPF (if third-party managed)
    { name = "google._domainkey"; type = "TXT"; }  # DKIM
    { name = "_dmarc"; type = "TXT"; }    # DMARC
  ];
};
```

### Deployment Integration

```bash
# Deploy infrastructure
nix run .#dns-sync -- /path/to/gandi-api-key
nix run .#gaming-host-1 switch
```

Or integrated into the existing deploy workflow:

```nix
# In flake.nix
packages.x86_64-linux.deploy-infra = pkgs.writeShellScriptBin "deploy-infra" ''
  nix run .#dns-sync -- /path/to/gandi-api-key
  # ... existing deploy logic ...
'';
```

## Migration Path

### Phase 1: Module + Topology Integration
1. Create `modules/dns-zones.nix` with option types (records, dynamicRecordNames, preservedRecordNames)
2. Create `lib/dns/from-topology.nix` to generate records from topology
3. Add `dns-sync` app to flake.nix (additive-only, no deletes)
4. Test with a single zone (`johnbargman.net`)
5. Manually verify preserved records are not touched

### Phase 2: Service Integration
1. Update service modules (nginx, squaremap) to declare DNS needs via `dns.zones`
2. Document which records are dynamic vs static vs preserved
3. `dynamic_domain_gandi.nix` continues to run independently

### Phase 3: Operational Maturity
1. Add `--dry-run` flag to `dns-sync` (show what would change without applying)
2. Add `--delete` flag with interactive confirmation
3. Add DNS validation to golden tests (verify declared records match reality)
4. Consider `nix run .#dns-diff` to show drift between config and live DNS

## What Stays Unchanged

| Component | Status | Reason |
|-----------|--------|--------|
| `dynamic_domain_gandi.nix` | **Stays** | Handles machines with dynamic IPs (laptops, DHCP hosts) |
| `acme_server.nix` | **Stays** | Handles TLS certificate provisioning via DNS-01 |
| Gandi as DNS provider | **Stays** | Existing infrastructure, no reason to change |
| Manual Gandi console edits | **Discouraged** | But preserved records are whitelisted against accidental deletion |

## Open Questions

1. **TXT record conflicts**: Root domain (`@`) may have both our-managed TXT records and third-party SPF. How do we handle partial TXT ownership? (Answer: whitelist the specific TXT name+type pair, or use `preservedRecordNames` for the root)

2. **CNAME at apex**: Gandi (and DNS spec) doesn't allow CNAME at root. If we need `johnbargman.net` to point to a machine, we need ALIAS/ANAME or an A record. How do we handle this?

3. **Dynamic record coordination**: `dynamic_domain_gandi.nix` updates records on its own timer. If `dns-sync` runs at the same time, could they conflict? (Answer: `dns-sync` skips `dynamicRecordNames`, so no conflict)

4. **Zone enumeration**: Gandi API can list all records in a zone. Should `dns-sync` use this to detect drift, or only check records we explicitly manage?

5. **Multiple domains**: Currently only `johnbargman.net`. If we add more domains (e.g., `platonic.systems`), how does the module scale?

## References

- [infrastructure-2 cf-dns implementation](/speed-storage/repo/platonic.systems/infrastructure-2/flake.nix) (lines 334-431)
- [infrastructure-2 octodns module](/speed-storage/repo/platonic.systems/infrastructure-2/modules/octodns.nix)
- [Gandi LiveDNS API v5 documentation](https://api.gandi.net/docs/livedns/)
- [Current dynamic_domain_gandi.nix](/speed-storage/repo/DarthPJB/NixOS-Configuration/services/dynamic_domain_gandi.nix)
- [Current acme_server.nix](/speed-storage/repo/DarthPJB/NixOS-Configuration/services/acme_server.nix)
- [topology.nix](/speed-storage/repo/DarthPJB/NixOS-Configuration/topology.nix)
