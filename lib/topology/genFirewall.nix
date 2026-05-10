{ lib }:
# genFirewall: settings -> hostname -> NixOS networking.firewall config
# settings is the output of mkFirewallSettings
# Returns the firewall configuration
settings: hostname:
let
  machineSettings = settings.machines.${hostname};
in
{
  networking.firewall = {
    allowedTCPPorts = machineSettings.tcpPorts;
    allowedUDPPorts = machineSettings.udpPorts;
    interfaces = machineSettings.interfaces;
  };
}
