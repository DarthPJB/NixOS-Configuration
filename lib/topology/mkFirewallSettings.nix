{ lib }:
# mkFirewallSettings: topology -> { machines = hostname -> { tcpPorts, udpPorts, interfaces } }
# Computes firewall ports for each machine based on topology
topology:
let
  # Find the hub: the machine that has peers defined
  hubName = lib.findFirst (name: topology.${name} ? peers) null (builtins.attrNames topology);

  # Helper to extract ports from nginx-proxy backends
  extractServicePorts = nginxProxy:
    let
      backends = builtins.attrValues nginxProxy;
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
  settings = lib.mapAttrs
    (hostname: machine:
      let
        isHub = hostname == hubName;
        standardTcpPorts = [ 22 1108 ]; # SSH, nixinate
        standardUdpPorts = if isHub then [ 2108 ] else [ ]; # WireGuard listen port
        nginxTcpPorts = if machine ? nginx-proxy then [ 443 ] else [ ];
        serviceTcpPorts = if machine ? nginx-proxy then extractServicePorts machine.nginx-proxy else [ ];
        extraTcpPorts = machine.firewall.tcp or [ ];
        extraUdpPorts = machine.firewall.udp or [ ];
        tcpPorts = lib.unique (standardTcpPorts ++ nginxTcpPorts ++ serviceTcpPorts ++ extraTcpPorts);
        udpPorts = lib.unique (standardUdpPorts ++ extraUdpPorts);
      in
      {
        inherit hostname;
        tcpPorts = tcpPorts;
        udpPorts = udpPorts;
        interfaces = { }; # Per-interface rules, empty for now
      }
    )
    topology;
in
{
  inherit hubName;
  machines = settings;
}
