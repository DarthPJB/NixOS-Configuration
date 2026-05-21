{ lib }:
# mkNginxSettings: topology -> { machines, warnings, errors }
# Returns nginx settings for machines that have nginx-proxy
topology:
let
  # Helper to resolve backend: hostname:port -> IP:port
  resolveBackend = backend:
    let
      parts = lib.splitString ":" backend;
      hostname = builtins.head parts;
      port = builtins.elemAt parts 1;
    in
    if builtins.elem (builtins.substring 0 1 hostname) [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" ]
    then backend  # Already an IP
    else
      let
        machine = topology.${hostname};
        ip = if machine ? wireguard then machine.wireguard else throw "No wireguard IP for ${hostname}";
      in
      "${ip}:${port}";

  # Build settings for each machine
  machines = lib.mapAttrs
    (hostname: machine:
      if ! (machine ? nginx-proxy) then null else
      let
        # Collect proxies
        proxies = lib.mapAttrs
          (domain: backend: {
            backend = resolveBackend backend;
            originalHostname = builtins.head (lib.splitString ":" backend);
          })
          machine.nginx-proxy;

        # ACME host: extract domain from first proxy key
        acmeHost =
          if proxies != { } then
            let
              firstDomain = builtins.head (builtins.attrNames proxies);
              parts = lib.splitString "." firstDomain;
            in
            builtins.concatStringsSep "." (lib.drop 1 parts)  # Drop subdomain
          else null;

        # Listen addresses: machine's LAN IPs
        listenAddresses =
          if machine ? lan then builtins.attrNames machine.lan else [ ];
      in
      {
        inherit hostname proxies acmeHost listenAddresses;
      }
    )
    topology;

  # Filter out null
  filteredMachines = lib.filterAttrs (_: v: v != null) machines;

  # Warnings: check for invalid backends
  warnings = lib.flatten (
    lib.mapAttrsToList
      (hostname: settings:
        lib.mapAttrsToList
          (domain: proxy:
            let
              backend = proxy.backend;
              parts = lib.splitString ":" backend;
            in
            if builtins.length parts != 2 then [ "Invalid backend format for ${domain}: ${backend}" ]
            else [ ]
          )
          settings.proxies
      )
      filteredMachines
  );

  errors = [ ];
in
{
  inherit warnings errors machines= filteredMachines;
}
