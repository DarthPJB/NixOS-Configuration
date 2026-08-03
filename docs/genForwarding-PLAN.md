# genForwarding.nix Implementation Plan

## Problem Statement

LAN clients on `10.88.128.0/24` lost WAN connectivity after deploying
`overlord-ii-planar-topology`. Root cause: `mktopology.nix` has no
`genForwarding` generator — the NAT masquerade and DNAT port forwarding
rules are never created.

On `main`, `core-router-topology.nix` imports `mkForwarding.nix` which
reads `topology.forwarding.{tcp,udp}` and generates the full nftables
NAT table. The branch replaced this module with `mktopology.nix` but
omitted the forwarding generator.

## Architecture Constraint

genForwarding.nix MUST follow the topology generator principle:
- Pure JSON-to-attrset function
- Reads ONLY topology JSON
- Produces `{ networking.nftables = { enable = true; ruleset = "..."; }; }`
- No module system, no hostname, no legacy paths

## Input Schema (topology JSON)

The `routes` array in `topology/cortex-alpha.json`:
```json
{
  "routes": [
    { "from": "wan", "port": 2208, "proto": "tcp", "to": "10.88.128.3:22", "reason": "SSH to local-nas" },
    { "from": "wan", "port": 27015, "proto": "tcp", "to": "10.88.128.88:27015", "reason": "Game server (TCP)" }
  ]
}
```

## Expected Output (nftables ruleset)

Must match the output of `main`'s `mkForwarding.nix`:
```nftables
table ip nat {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    iifname "enp2s0" tcp dport 2208 dnat to 10.88.128.3:22
    iifname "enp2s0" tcp dport 27015 dnat to 10.88.128.88:27015
    ...
  };
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    oifname "enp2s0" ip saddr 10.88.128.0/24 masquerade
  };
}
```

## Key Differences from Old Schema

| Old (`main`) | New (branch JSON) |
|-------------|-------------------|
| `topology.forwarding.tcp[].{port, dest}` | `topology.routes[].{port, proto, to}` |
| `topology.forwarding.udp[].{port, dest}` | Same array, `proto` field distinguishes |
| `topology.lan.wanInterface` | Derived from coordinate with `-wan` suffix |
| `topology.lan.subnet` | Derived from coordinate with `.lan` suffix |

## Phases

### Phase A: Implement genForwarding.nix

**Step A1**: Create `lib/topology/genForwarding.nix`

Prompt for bellana-deepseek:
> Create `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genForwarding.nix`
>
> This is a pure topology generator following the same pattern as genFirewall.nix,
> genDns.nix, genNginx.nix, genBackup.nix, genNetwork.nix.
>
> Requirements:
> 1. Takes the full topology JSON as input
> 2. Reads `topology.routes` array
> 3. Derives the WAN interface from coordinates where plane_name ends with "-wan" or ".wan"
> 4. Derives the LAN subnet from coordinates where plane_name ends with ".lan" or is a hub_of entry
> 5. Generates nftables DNAT rules for each route entry
> 6. Generates masquerade postrouting rule for LAN → WAN NAT
> 7. Returns `{ networking.nftables = { enable = true; ruleset = "..."; }; }`
> 8. Returns `{ }` if no routes exist
>
> Route entry schema:
> ```json
> { "from": "wan", "port": 2208, "proto": "tcp", "to": "10.88.128.3:22", "reason": "..." }
> ```
>
> The `from` field is always "wan" (the WAN interface).
> The `proto` field is "tcp" or "udp".
> The `to` field is "ip:port" (DNAT destination).
>
> The generator MUST:
> - Include the standard topology principle header comment (copy from genFirewall.nix)
> - Use `lib` parameter pattern: `{ lib }:`
> - Handle empty routes array gracefully (return `{ }`)
> - Use lib.concatStringsSep for rule assembly
> - Match the nftables syntax from the old mkForwarding.nix exactly:
>   - `iifname "${wanInterface}" ${proto} dport ${port} dnat to ${dest}`
>   - `oifname "${wanInterface}" ip saddr ${subnet} masquerade`
>
> Reference files:
> - `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genFirewall.nix` (pattern)
> - `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/genNetwork.nix` (coordinate parsing)
> - Old mkForwarding.nix (nftables syntax — retrieved via `git show main:lib/topology/mkForwarding.nix`)
> - `/speed-storage/bargman-tech/NixOS-Configuration/topology/cortex-alpha.json` (routes schema)

**Step A2**: Validate genForwarding.nix produces correct output

Prompt for bellana-deepseek:
> Test genForwarding.nix by evaluating it against cortex-alpha's topology JSON.
>
> Run:
> ```bash
> nix eval --json --expr '
>   let
>     lib = (import <nixpkgs> {}).lib;
>     gen = import ./lib/topology/genForwarding.nix { inherit lib; };
>     topology = builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json);
>   in gen topology
> ' | jq .
> ```
>
> Verify the output contains:
> - `networking.nftables.enable = true`
> - `networking.nftables.ruleset` with all 14 DNAT rules from cortex-alpha.json routes
> - Masquerade postrouting rule for `10.88.128.0/24` via WAN interface
>
> Compare the ruleset content against the old mkForwarding.nix output:
> ```bash
> git show main:lib/topology/mkForwarding.nix
> ```
>
> The DNAT rules and masquerade rule MUST match.

### Phase B: Wire into mktopology.nix

**Step B1**: Add genForwarding to mktopology.nix

Prompt for bellana-deepseek:
> Wire genForwarding.nix into `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/mktopology.nix`
>
> Changes needed:
> 1. Add import: `genForwarding = import ./genForwarding.nix { inherit lib; };`
>    (after the genNetwork import, around line 55)
>
> 2. Add to mkMachineConfig fold (after genNetwork, before DNS):
>    ```nix
>    # ── Forwarding/NAT (conditional on topology.routes) ─────
>    (if topology ? routes then genForwarding topology else { })
>    ```
>
> Reference: `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/mktopology.nix`
> The genForwarding call should be placed AFTER genNetwork and BEFORE genDns in the
> mkMachineConfig function's filter list.

### Phase C: Validate against golden and main

**Step C1**: Run golden validation for cortex-alpha

Prompt for bellana-deepseek:
> Run golden validation for cortex-alpha:
> ```bash
> nix run .#validate-goldens -- cortex-alpha 2>&1
> ```
>
> If it fails, regenerate the golden and inspect the diff:
> ```bash
> nix run .#dump-config -- cortex-alpha > /tmp/cortex-alpha-new.json
> diff /tmp/cortex-alpha-main.json /tmp/cortex-alpha-new.json
> ```
>
> The nftables ruleset in the golden MUST now contain the NAT table.
> Compare against main's nftables config.
>
> Key validation: the `networking.nftables.ruleset` field must contain
> the DNAT rules and masquerade rule.

**Step C2**: Validate all other machines still pass

Prompt for bellana-deepseek:
> Run golden validation for ALL machines to ensure no regressions:
> ```bash
> for m in $(ls machines/); do
>   echo -n "$m: "
>   nix run .#validate-goldens -- "$m" 2>&1 | tail -1
> done
> ```
>
> All 19 machines must pass. If any fail, investigate and fix.

**Step C3**: Commit

Prompt for bellana-deepseek:
> Stage and commit all changes:
> ```bash
> git add -A
> git commit -m "feat: add genForwarding.nix — restore NAT masquerade for LAN clients
>
> mktopology was missing a forwarding generator. LAN clients lost WAN
> connectivity because the nftables NAT masquerade rule was never created.
>
> - Add lib/topology/genForwarding.nix (routes → nftables NAT table)
> - Wire into mktopology.nix (conditional on topology.routes)
> - Regenerate cortex-alpha golden
>
> Fixes: LAN clients can now NAT through cortex-alpha to WAN"
> ```

## Verification Criteria

1. genForwarding.nix exists and follows generator pattern
2. mktopology.nix calls genForwarding conditionally on `topology.routes`
3. cortex-alpha golden contains nftables NAT table with all 14 DNAT rules
4. cortex-alpha golden contains masquerade postrouting rule
5. All 19 machines pass golden validation
6. The nftables ruleset matches main's output
