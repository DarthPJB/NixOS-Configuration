{ lib }:
# mkNginxSettings: per-machine topology -> { machines, warnings, errors }
# Extracts nginx settings from per-machine topology data.
# Must match production mkNginxProxies.nix data consumption.
# The generator (genNginx.nix) replicates mkNginxProxies.nix output logic.
#
# Phase 5 (C): Per-machine vhosts support. If a machine has
# vhosts (the new schema), the function delegates to genNginx.nix
# for per-subnet vhost stanzas. Otherwise, the original extraction logic
# is used (backward compatible).
topology:
let
  utils = import ./utils.nix { inherit lib; };
  inherit (utils) safeLookup;

  # ── Per-machine implementation ──────────────────────────────
  # This follows the `s: hostname:` pattern from the step 5.1 sketch,
  # while keeping the topology-level signature for callers.
  # s: single machine's topology data
  # hostname: the machine's hostname
  mkPerMachine = s: hostname:
    # Phase 5 (C): vhosts path — per-subnet stanzas from new schema.
    # When vhosts is present, pass the raw data through for the
    # generator (genNginx.nix) to consume.
    # This path is dormant until a machine has vhosts in its topology.
    if s ? vhosts then
      {
        inherit hostname;
        # Raw vhosts data for downstream generators
        vhosts = s.vhosts;
      }
    # Legacy path (unchanged behaviour)
    else if !(s ? nginx) then null
    else
      let
        nginx = s.nginx;
        lan = s.lan or { };
      in
      {
        inherit hostname;

        # ACME host — wildcard cert domain
        acmeHost = safeLookup nginx "acmeHost" (s.domain or "local");

        # Global listen addresses (used by base hosts by default)
        listenAddresses = safeLookup nginx "listenAddresses" [ ];

        # Default listen addresses for proxy hosts
        # Uses explicit proxyListenAddresses if set, otherwise [gateway, host-IP]
        defaultListenAddresses = safeLookup nginx "proxyListenAddresses" [
          (lan.gateway or "0.0.0.0")
          ((lan.hosts or { }).${s.hostname or ""}.ip or "0.0.0.0")
        ];

        # Proxy definitions — each is { backend, forceSSL?, websockets?, listenAddresses? }
        proxies = safeLookup nginx "proxies" { };

        # Base virtual hosts — static content or default responses
        baseVhosts = safeLookup nginx "baseVhosts" { };

        # Domain for ACME fallback
        domain = s.domain or "local";
      };

  # mapAttrs calls f key value; mkPerMachine takes s (data) hostname (name)
  # so we wrap to swap the arguments
  machines = lib.mapAttrs (hostname: s: mkPerMachine s hostname) topology;

  filteredMachines = lib.filterAttrs (_: v: v != null) machines;

  warnings = [ ];
  errors = [ ];
in
{
  inherit warnings errors;
  machines = filteredMachines;
}
