{ lib }:
# mkFirewallSettings: topology -> { machines, warnings, errors }
# Computes firewall ports for each machine based on topology
topology:
let
  # Determine which machines are serving as hubs
  isServing = lib.genAttrs (lib.attrNames topology) (hostname:
    lib.any (name: topology.${name} ? hub && topology.${name}.hub == hostname) (lib.attrNames topology)
  );

  # Helper to extract ports from nginx-proxy backends
  extractServicePorts = nginxProxy:
    let
      backends = lib.mapAttrsToList (_: proxy: proxy) nginxProxy;
      ports = builtins.map
        (backend:
          let
            parts = builtins.split ":" backend;
            portStr = if builtins.length parts >= 2 then builtins.elemAt parts 1 else null;
          in
          if portStr != null && builtins.isString portStr then builtins.toInt portStr else null
        )
        backends;
    in
    lib.unique (lib.filter (x: x != null) ports);

  # Build settings for each machine
  machines = lib.mapAttrs
    (hostname: machine: {
      inherit hostname;
      tcpPorts = lib.unique ([ 22 1108 ] ++
        (if machine ? nginx-proxy then [ 443 ] ++ extractServicePorts machine.nginx-proxy else [ ]) ++
        (if machine ? firewall then machine.firewall.allowedTCPPorts or [ ] else [ ]));
      udpPorts = lib.unique ((if isServing.${hostname} then [ 2108 ] else [ ]) ++
        (if machine ? firewall then machine.firewall.allowedUDPPorts or [ ] else [ ]));
      interfaces = if machine ? lan then lib.mapAttrs (_: _: { }) machine.lan else { };
    })
    topology;

  # No warnings or errors for now
  warnings = [ ];
  errors = [ ];
in
{
  inherit warnings errors machines;
}
