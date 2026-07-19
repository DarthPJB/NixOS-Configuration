# Network Topology Golden Test System

## Overview

The golden test system is a deterministic JSON dump + diff workflow that catches unintended configuration drift across revisions. Every `nixosConfiguration` in the flake has a corresponding golden file in `goldens/<machine>.json`. `nix flake check` runs the dump for every machine and diffs against the golden. A mismatch is a **build error** — exactly what we want for a system that declares "topology defines configuration."

## The Generator (one, simple, deterministic)

**File:** `lib/serialize-config.nix`

**API:** `serializeConfig :: Config -> JSON`

The generator is a single function. It takes a NixOS config and returns a flat path-keyed JSON object. Example output shape:

```json
{
  "boot.kernel.sysctl": { ... },
  "boot.loader": { ... },
  "boot.supportedFilesystems": [ ... ],
  "environment.systemPackages": [ ... ],
  "networking.domain": "...",
  "networking.firewall": { ... },
  "networking.hostId": "...",
  "networking.hostName": "...",
  "networking.interfaces": { ... },
  "networking.nameservers": [ ... ],
  "networking.nat": { ... },
  "networking.nftables": { ... },
  "networking.tailscale": { ... },
  "networking.wireguard": { ... },
  "security.acme": { ... },
  "services.dnsmasq": { ... },
  "services.nginx": { ... },
  "services.openldap": { ... },
  "services.openssh": { ... },
  "services.prometheus": { ... },
  "services.tailscale": { ... },
  "systemd.services.tailscale-udp-gro": { ... },
  "time.timeZone": "..."
}
```

The function is *not* a config serializer that tries to dump the entire config. It extracts 23 specific safe sections and serializes each one. Sections that fail to evaluate (e.g. due to lazy evaluation, exceptions, or circular references) are recorded as `"<eval-error>"` rather than crashing the dump. This is the right tradeoff: a single broken section should not block the entire golden test.

## The Workflow

```bash
# Generate the current config for one machine
nix run .#dump-config -- cortex-alpha | jq -S . > /tmp/current.json

# Compare to the golden
diff -u goldens/cortex-alpha.json /tmp/current.json
```

If the diff is empty, the config matches the golden. If the diff is non-empty:
- **Real change** (e.g. you added a new vhost): accept it. `nix run .#dump-config -- cortex-alpha > goldens/cortex-alpha.json` regenerates the golden. Commit.
- **Regression** (e.g. you changed a generator and the output is wrong): fix the generator. Do NOT regenerate the golden.

## Running on All Configurations (CI)

The `checks."x86_64-linux"` block in `flake.nix` defines per-machine golden checks. The pattern is:

```nix
checks."x86_64-linux".network-config-<machine> = nixpkgs.writeShellApplication {
  name = "network-config-<machine>";
  runtimeInputs = [ nixpkgs.jq ];
  text = ''
    nix run .#dump-config -- <machine> | jq -S . > /tmp/current.json
    if diff -u ${self}/goldens/<machine>.json /tmp/current.json; then
      echo "✓ Network config matches golden for <machine>"
    else
      echo "✗ Network configuration has changed from golden!"
      exit 1
    fi
  '';
};
```

This is run for every machine in the flake on every `nix flake check`. The current `checks."x86_64-linux"` block has one example (`network-config-cortex-alpha`); the multi-horizon plan rev 4 should generalize this to all machines.

## The Hand-Edited Truths

Three categories of hand-edited data:

1. **Per-host topology** — `topology/<machine>.json`. Declares the machine's role, coordinate (which planes it sits on), planes it serves (if hub), and properties (external IP, local interfaces, etc.).
2. **Shared topology** — `topology/shared.json` (or `topology/shared.nix`). Cross-host data; hand-edited, NOT generated. The generator never produces topology source (IFD is forbidden).
3. **Goldens** — `goldens/<machine>.json`. The prior implementation's truth. The contract.

The generator is a pure function: `generator :: Topology -> Config`. Given the topology, the config is determined. The generator does not modify the topology; it does not produce topology source.

## "What was" vs "What will be"

- **Topology JSON** = "what will be" (the desired state, hand-edited, future)
- **Generated config** = "what is" (the actual state, after generation)
- **Golden JSON** = "what was" (the prior implementation's truth, the contract)

The operator's loop:
1. Edit `topology/cortex-alpha.json` to declare a new plane, new route, new vhost.
2. Run `nix run .#check-network -- cortex-alpha` (or `nix flake check`).
3. The diff is the answer:
   - If the diff matches the desired change, regenerate the golden, commit.
   - If the diff is a regression, inspect the generator: is the data right? Is the generator code right?
4. Debug: feed correct data to the generator, observe the output, fix the generator.

## Dead Code (to be deleted)

**`lib/golden_generator.nix`** is dead code from 2026-07-11 (commit `4b967b0`). Its comment header says "real-topology/default.nix" — it was copied from the old `real-topology/` directory when that was renamed to `topology/`. It defines a different JSON shape (`safeOptions` / `generateGolden`) but is not referenced anywhere in the repo. **Action: delete in a cleanup pass.**

**`lib/golden_coverage.nix`** is a separate tool — a coverage audit that checks whether every machine in `nixosConfigurations` has a corresponding golden. Imported by `flake.nix` as `coverage` in the `topology-coverage` check. This is not a config serializer; it's an audit. Can be kept or removed independently of the generator cleanup.

## Related Files

- `AGENTS.md` — General agent instructions
- `documentation/tailscale-subnet-routers.md` — Tailscale implementation synthesis
- `documentation/topology-migration-guide.md` — Guide for migrating machines to topology-driven configuration
- `lib/serialize-config.nix` — The generator (the only one)
- `flake.nix` — `dump-config` and `check-network` apps; `checks."x86_64-linux"` block
- `goldens/<machine>.json` — One per machine in `nixosConfigurations`
