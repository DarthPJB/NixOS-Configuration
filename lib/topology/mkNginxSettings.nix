{ lib }:
# mkNginxSettings: per-machine topology -> { machines, warnings, errors }
# Extracts nginx settings from per-machine topology data.
# Must match production mkNginxProxies.nix data consumption.
# The generator (genNginx.nix) replicates mkNginxProxies.nix output logic.
topology:
let
  utils = import ./utils.nix { inherit lib; };
  inherit (utils) safeLookup;

  machines = lib.mapAttrs
    (hostname: machine:
      if !(machine ? nginx) then null else
      let
        nginx = machine.nginx;
        lan = machine.lan or { };
      in
      {
        inherit hostname;

        # ACME host — wildcard cert domain
        acmeHost = safeLookup nginx "acmeHost" (machine.domain or "local");

        # Global listen addresses (used by base hosts by default)
        listenAddresses = safeLookup nginx "listenAddresses" [ ];

        # Default listen addresses for proxy hosts
        # Uses explicit proxyListenAddresses if set, otherwise [gateway, host-IP]
        defaultListenAddresses = safeLookup nginx "proxyListenAddresses" [
          (lan.gateway or "0.0.0.0")
          ((lan.hosts or { }).${machine.hostname or ""}.ip or "0.0.0.0")
        ];

        # Proxy definitions — each is { backend, forceSSL?, websockets?, listenAddresses? }
        proxies = safeLookup nginx "proxies" { };

        # Base virtual hosts — static content or default responses
        baseVhosts = safeLookup nginx "baseVhosts" { };

        # Domain for ACME fallback
        domain = machine.domain or "local";
      }
    )
    topology;

  filteredMachines = lib.filterAttrs (_: v: v != null) machines;

  warnings = [ ];
  errors = [ ];
in
{
  inherit warnings errors;
  machines = filteredMachines;
}
