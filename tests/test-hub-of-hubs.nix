{ ... }:
{
  # Test topology for hub-of-hubs
  cortex-alpha = {
    wireguard = "10.88.127.1";
    lan = { "10.88.128.1" = "enp3s0"; };
    uplink = { "82.5.173.252" = "enp2s0"; };
    peers = [ "building-b" ];
    nginx-proxy = {
      "test.johnbargman.net" = "local-nas:80";
    };
  };

  building-b = {
    wireguard = "10.88.127.100";
    lan = { "10.89.128.1" = "enp3s0"; };
    peers = [ "office-1" "office-2" ];
    hub = "cortex-alpha";
    nginx-proxy = {
      "building.johnbargman.net" = "office-1:80";
    };
  };

  office-1 = {
    wireguard = "10.88.127.101";
    hub = "building-b";
  };

  office-2 = {
    wireguard = "10.88.127.102";
    hub = "building-b";
  };

  local-nas = {
    wireguard = "10.88.127.3";
    lan = { "10.88.128.3" = "enp0s31f6"; };
  };
}