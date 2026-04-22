# real-topology/cortex-alpha.nix
# This file represents the physical network reality for cortex-alpha.
# It is the single source of truth for all routing, addressing, and capabilities.
{ ... }:
{
  domain = "johnbargman.net";

  lan = {
    subnet = "10.88.128.0/24";
    gateway = "10.88.128.1";
    interface = "enp3s0";
    wanInterface = "enp2s0";

    hosts = {
      lindacore-88 = {
        ip = "10.88.128.88";
        mac = "18:c0:4d:8d:53:6d";
        hostname = "LINDACORE";
        routing = {
          tailscale = true;
          wireguard = false;
        };
        services = [ "gaming" "high-bandwidth" ];
      };

      nas = {
        ip = "10.88.128.3";
        mac = "f8:32:e4:b9:77:0b";
        hostname = "local-nas";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ "storage" "monitoring" ];
      };

      # Add more hosts as reality expands
    };
  };

  forwarding = {
    tcp = [
      { from = "wan"; port = 2208; to = "10.88.128.3:22"; }
    ];
    udp = [ ];
  };

  tailscale = {
    subnetRouter = true;
    advertisedHosts = [ "lindacore-88" ];
  };
}
