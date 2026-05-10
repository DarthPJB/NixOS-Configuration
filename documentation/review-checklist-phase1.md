# Review Checklist: Phase 1 Readiness

## topology.nix
- [ ] All machines declared under `nixosConfigurations` are represented with entries in `topology.nix`
- [ ] WireGuard IPs follow the 10.88.127.X convention and do not overlap
- [ ] LAN IP/interface mappings mirror the values from the existing per-machine configs
- [ ] Hub (`cortex-alpha`) exposes a `peers` list that names every WireGuard client
- [ ] Hub defines `nginx-proxy` entries that match the live proxy backends and ports
- [ ] Hub contains an `uplink` section that binds the WAN IP to the correct physical interface
- [ ] No duplicate host entries exist (unique attrset keys)
- [ ] The file can be parsed cleanly by `nix` (e.g., `nix --option builders '' eval --expr 'import ./topology.nix { }'`)

## mkWireguardSettings.nix
- [ ] Follows the `{ lib }: topology: { ... }` signature described in the architecture document
- [ ] Reads public keys from `secrets/public_keys/wireguard/wg_${hostname}_pub` by convention
- [ ] Missing public keys generate warnings but do not abort the entire transform
- [ ] The returned data structure is flat and indexed by hostname for easy generator consumption
- [ ] Includes all required fields (interface, listenPort, hubName, hubIps, machineIp, peers, warnings)
- [ ] Does not reference `self` so it can be imported from any context
- [ ] The file parses without syntax errors

## genWireguard.nix
- [ ] Implements the `{ lib }: settings: hostname: { ... }` signature that generators share
- [ ] Produces a hub config (cortex-alpha) with a listen port and peer list for every non-hub peer
- [ ] Produces a client config with exactly the hub endpoint when invoked for any other hostname
- [ ] Contains no direct file I/O (relies on precomputed `settings`)
- [ ] Remains a pure function for easier unit testing
- [ ] Emits valid `networking.wireguard.interfaces` entries for both hub and client cases
- [ ] The file parses without syntax errors

## Integration
- [ ] `nix --option builders '' flake check` still succeeds on the current codebase
- [ ] The golden test for `cortex-alpha` (`real-topology/golden/cortex-alpha.json`) still matches the generated output
- [ ] No existing files referenced by the traditional architecture (e.g., `modules/core-router.nix`) are broken while the new transformer/generator files land
