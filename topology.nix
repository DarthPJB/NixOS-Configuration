{ ... }:
{
  cortex-alpha = {
    wireguard = "10.88.127.1";
    lan = { "10.88.128.1" = "enp3s0"; };
    uplink = { "82.5.173.252" = "enp2s0"; };
    peers = [
      "LINDA"
      "alpha-one"
      "alpha-three"
      "building-b"
      "cluster-box"
      "cortex-alpha"
      "display-0"
      "display-1"
      "display-2"
      "dlyon"
      "gaming-host-1"
      "grimterm"
      "local-nas"
      "print-controller"
      "remote-builder"
      "remote-worker"
      "storage-array"
      "terminal-nx-01"
      "terminal-zero"
    ];
  };

  local-nas = {
    wireguard = "10.88.127.3";
    lan = { "10.88.128.3" = "enp0s31f6"; };
    hub = "cortex-alpha";
  };

  alpha-one = {
    wireguard = "10.88.127.108";
    lan = { "10.88.128.108" = "enp0s31f6"; };
    hub = "cortex-alpha";
  };

  alpha-three = {
    wireguard = "10.88.127.107";
    hub = "cortex-alpha";
  };

  LINDA = {
    wireguard = "10.88.127.88";
    lan = { "10.88.128.88" = "enp0s31f6"; };
    hub = "cortex-alpha";
  };

  print-controller = {
    wireguard = "10.88.127.30";
    lan = { "10.88.128.10" = "wlan0"; };
    hub = "cortex-alpha";
  };

  terminal-zero = {
    wireguard = "10.88.127.20";
    lan = { "10.88.128.20" = "enp0s25"; };
    hub = "cortex-alpha";
  };

  terminal-nx-01 = {
    wireguard = "10.88.127.21";
    lan = { "10.88.128.22" = "enp0s31f6"; };
    hub = "cortex-alpha";
  };

  display-1 = {
    wireguard = "10.88.127.41";
    hub = "cortex-alpha";
  };

  display-2 = {
    wireguard = "10.88.127.42";
    hub = "cortex-alpha";
  };

  remote-builder = {
    wireguard = "10.88.127.51";
    hub = "cortex-alpha";
  };

  gaming-host-1 = {
    wireguard = "10.88.127.52";
    hub = "cortex-alpha";
  };

  remote-worker = {
    wireguard = "10.88.127.50";
    hub = "cortex-alpha";
  };

  storage-array = {
    wireguard = "10.88.127.4";
    hub = "cortex-alpha";
  };

  display-0 = {
    wireguard = "10.88.127.40";
  };

  dlyon = {
    wireguard = "10.88.127.210";
  };

  grimterm = {
    wireguard = "10.88.127.212";
  };

  cluster-box = {
    wireguard = "10.88.127.211";
  };

  alpha-two = {
    wireguard = "10.88.127.109";
  };

  # Hub-of-hubs example
  building-b = {
    wireguard = "10.88.127.100";
    lan = { "10.89.128.1" = "enp3s0"; };
    peers = [ "office-1" "office-2" ];
    hub = "cortex-alpha";
  };

  office-1 = {
    wireguard = "10.88.127.101";
    hub = "building-b";
  };

  office-2 = {
    wireguard = "10.88.127.102";
    hub = "building-b";
  };
}
