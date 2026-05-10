{ lib }:
# mkNginxSettings: topology -> nginx settings for the hub
# Reads nginx-proxy from topology and resolves backends to IPs
# Returns settings for nginx configuration
topology:
let
  # Find the hub: the machine that has nginx-proxy defined
  hubName = lib.findFirst (name: topology.${name} ? nginx-proxy) null (builtins.attrNames topology);

  # Helper to resolve backend: hostname:port -> IP:port
  resolveBackend = backend:
    let
      parts = lib.splitString ":" backend;
      hostname = builtins.head parts;
      port = builtins.elemAt parts 1;
    in
    if lib.strings.hasPrefix (lib.strings.charAt hostname 0) "0123456789"
    then backend  # Already an IP
    else
      let
        machine = topology.${hostname};
        ip = if machine ? wireguard then machine.wireguard else throw "No wireguard IP for ${hostname}";
      in
      "${ip}:${port}";

  # Collect proxies
  proxies =
    if hubName != null then
      lib.mapAttrs
        (domain: backend: {
          backend = resolveBackend backend;
          originalHostname = builtins.head (lib.splitString ":" backend);
        })
        topology.${hubName}.nginx-proxy
    else { };

  # ACME host: extract domain from first proxy key
  acmeHost =
    if proxies != { } then
      let
        firstDomain = builtins.head (builtins.attrNames proxies);
        parts = lib.splitString "." firstDomain;
      in
      builtins.concatStringsSep "." (lib.drop 1 parts)  # Drop subdomain
    else null;

  # Listen addresses: hub's LAN IPs and WireGuard IP
  listenAddresses =
    if hubName != null then
      let
        hub = topology.${hubName};
        lanIps = if hub ? lan then builtins.attrNames hub.lan else [ ];
        wgIp = [ hub.wireguard ];
      in
      lanIps ++ wgIp
    else [ ];

  # Warnings: check for missing machines or invalid backends
  warnings = lib.flatten (
    if hubName == null then [ "No hub with nginx-proxy found" ]
    else
      lib.mapAttrsToList
        (domain: proxy:
          let
            backend = proxy.backend;
            parts = lib.splitString ":" backend;
          in
          if builtins.length parts != 2 then [ "Invalid backend format for ${domain}: ${backend}" ]
          else if ! lib.strings.hasPrefix (lib.strings.charAt (builtins.head parts) 0) "0123456789" then [ ]
          else [ ]  # Already checked in resolveBackend
        )
        proxies
  );
in
{
  inherit hubName proxies acmeHost listenAddresses warnings;
}
