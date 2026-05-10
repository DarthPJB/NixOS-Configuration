{...}:
{
  cortex-alpha = {
    wireguard = "10.88.127.1";
    lan = { "10.88.128.1" = "enp3s0"; };
    uplink = { "82.5.173.252" = "enp2s0"; };
    peers = [
      "LINDA"
      "alpha-one"
      "alpha-three"
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
    nginx-proxy = {
      "print-controller.johnbargman.net" = "print-controller:80";
      "code.johnbargman.net" = "local-nas:80";
      "git.johnbargman.net" = "local-nas:80";
      "prometheus.johnbargman.net" = "local-nas:8080";
      "grafana.johnbargman.net" = "local-nas:3101";
      "ap.johnbargman.net" = "10.88.128.2:80";
    };
  };

  local-nas = {
    wireguard = "10.88.127.3";
    lan = { "10.88.128.3" = "enp0s31f6"; };
  };

  alpha-one = {
    wireguard = "10.88.127.108";
    lan = { "10.88.128.108" = "enp0s31f6"; };
  };

  alpha-three = {
    wireguard = "10.88.127.107";
  };

  LINDA = {
    wireguard = "10.88.127.88";
    lan = { "10.88.128.88" = "enp0s31f6"; };
  };

  print-controller = {
    wireguard = "10.88.127.30";
    lan = { "10.88.128.10" = "wlan0"; };
  };

  terminal-zero = {
    wireguard = "10.88.127.20";
    lan = { "10.88.128.20" = "enp0s25"; };
  };

  terminal-nx-01 = {
    wireguard = "10.88.127.21";
    lan = { "10.88.128.22" = "enp0s31f6"; };
  };

  display-0 = {
    wireguard = "10.88.127.40";
  };

  display-1 = {
    wireguard = "10.88.127.41";
  };

  display-2 = {
    wireguard = "10.88.127.42";
  };

  remote-builder = {
    wireguard = "10.88.127.51";
  };

  gaming-host-1 = {
    wireguard = "10.88.127.52";
  };

  remote-worker = {
    wireguard = "10.88.127.50";
  };

  storage-array = {
    wireguard = "10.88.127.4";
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
}