{ lib }:
# mkFirewallSettings: topology -> { machines = hostname -> { tcpPorts, udpPorts, interfaces } }
# Computes firewall ports for each machine based on topology
topology:
let
  validate = import ./validate.nix { inherit lib; };
  crossRefValidation = validate.validateCrossReferences topology;
let
  hubName = topology.hostname;

  # Merge machine configs: hosts + hub extras
  machines = lib.mapAttrs (hostname: host: host // (if hostname == hubName then {
    firewall = topology.firewall;
    nginx = topology.nginx;
    wireguard = topology.wireguard;
  } else {} )) topology.lan.hosts;

  # Helper to extract ports from nginx-proxy backends
  extractServicePorts = nginxProxy:
    let
      backends = lib.mapAttrsToList (_: proxy: proxy.backend) nginxProxy;
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
        firewallConfig = machine.firewall or {};
      in
      if machine ? firewall then {
        inherit hostname;
        tcpPorts = firewallConfig.allowedTCPPorts or [];
        udpPorts = firewallConfig.allowedUDPPorts or [];
        interfaces = firewallConfig.interfaces or {};
      } else
      let
        standardTcpPorts = [ 22 1108 ]; # SSH, nixinate
        standardUdpPorts = if isHub then [ 2108 ] else [ ]; # WireGuard listen port
        nginxTcpPorts = if machine ? nginx then [ 443 ] else [ ];
        serviceTcpPorts = if machine ? nginx then extractServicePorts machine.nginx.proxies else [ ];
        extraTcpPorts = firewallConfig.allowedTCPPorts or [ ];
        extraUdpPorts = firewallConfig.allowedUDPPorts or [ ];
        tcpPorts = lib.unique (standardTcpPorts ++ nginxTcpPorts ++ serviceTcpPorts ++ extraTcpPorts);
        udpPorts = lib.unique (standardUdpPorts ++ extraUdpPorts);
      in
      {
        inherit hostname;
        tcpPorts = tcpPorts;
        udpPorts = udpPorts;
        interfaces = firewallConfig.interfaces or {}; # Use interfaces if defined
      }
    )
    machines;
  # Cross-reference validation errors
  errors = crossRefValidation.errors;
in
{
  inherit hubName errors;
  machines = settings;
}
