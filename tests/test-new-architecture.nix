# tests/test-new-architecture.nix
# Test harness for validating new topology-driven architecture
{ lib
, ...
}:

let
  # Import topology
  topology = import ../real-topology/cortex-alpha.nix { inherit lib; };

  # Import transformers
  wireguardSettings = (import ../lib/topology/mkWireguardSettings.nix { inherit lib; }) topology;
  nginxSettings = (import ../lib/topology/mkNginxSettings.nix { inherit lib; }) topology;
  firewallSettings = (import ../lib/topology/mkFirewallSettings.nix { inherit lib; }) topology;
  dnsSettings = (import ../lib/topology/mkDnsSettings.nix { inherit lib; }) topology;

  # Generate configs for cortex-alpha
  hostname = "cortex-alpha";
  wireguardConfig = (import ../lib/topology/genWireguard.nix { inherit lib; }) wireguardSettings hostname;
  nginxConfig = (import ../lib/topology/genNginx.nix { inherit lib; }) nginxSettings hostname;
  firewallConfig = (import ../lib/topology/genFirewall.nix { inherit lib; }) firewallSettings hostname;
  dnsConfig = (import ../lib/topology/genDns.nix { inherit lib; }) dnsSettings hostname;

  # Mock config object with generated attributes
  config = {
    networking.hostName = hostname;
    networking.hostId = null; # Not set by new architecture
    networking.domain = null;
    networking.nameservers = [];
    networking.interfaces = {}; # Not set by new architecture
    networking.nat.enable = false;
    networking.nat.internalInterfaces = [];
    networking.nat.externalInterface = null;
    networking.nftables.enable = false;
    networking.nftables.ruleset = null;
    networking.firewall = firewallConfig.networking.firewall;
    networking.wireguard.enable = false;
    services.tailscale.enable = false;
    services.tailscale.useRoutingFeatures = null;
    services.tailscale.extraSetFlags = [];
    networking.tailscale.advertisedRoutes = [];
    services.dnsmasq.enable = dnsConfig.services.dnsmasq.enable or false;
    services.dnsmasq.settings = dnsConfig.services.dnsmasq.settings or {};
    services.dnsmasq.port = null;
    services.nginx.enable = nginxConfig.services.nginx.enable or false;
    services.nginx.virtualHosts = nginxConfig.services.nginx.virtualHosts or {};
    services.prometheus.exporters.node.enable = false;
    services.prometheus.exporters.node.port = null;
    services.prometheus.exporters.dnsmasq.enable = false;
    services.prometheus.exporters.dnsmasq.port = null;
    boot.kernel.sysctl = {}; # Not set
    time.timeZone = null;
    environment.systemPackages = [];
    systemd.services.tailscale-udp-gro.enable = false;
    security.acme.defaults.email = null;
    security.acme.certs = {};
  };

  # Import safeOptions from real-topology/default.nix
  utils = import ../lib/topology/utils.nix { inherit lib; };
  inherit (utils) normalizePath;

  safeOptions = {
    # Basic identity
    "networking.hostName" = config: config.networking.hostName;
    "networking.hostId" = config: config.networking.hostId;
    "networking.domain" = config: config.networking.domain or null;
    "networking.nameservers" = config: config.networking.nameservers or [ ];

    # Network interfaces (physical interface configuration)
    "networking.interfaces" =
      config:
      let
        ifaces = config.networking.interfaces;
        # Extract key interface settings
        extractIface = iface: {
          useDHCP = iface.useDHCP or false;
          ipv4 = {
            addresses = map
              (addr: {
                inherit (addr) address prefixLength;
              })
              (iface.ipv4.addresses or [ ]);
          };
          ipv6 = {
            addresses = map
              (addr: {
                inherit (addr) address prefixLength;
              })
              (iface.ipv6.addresses or [ ]);
          };
        };
      in
      lib.mapAttrs (name: extractIface) ifaces;

    # NAT and firewall
    "networking.nat.enable" = config: config.networking.nat.enable or false;
    "networking.nat.internalInterfaces" = config: config.networking.nat.internalInterfaces or [ ];
    "networking.nat.externalInterface" = config: config.networking.nat.externalInterface or null;
    "networking.nftables.enable" = config: config.networking.nftables.enable;
    "networking.nftables.ruleset" =
      config:
      let
        ruleset = config.networking.nftables.ruleset;
      in
      if builtins.isString ruleset then "<ruleset-string>" else ruleset;
    "networking.firewall.allowedTCPPorts" = config: config.networking.firewall.allowedTCPPorts;
    "networking.firewall.allowedUDPPorts" = config: config.networking.firewall.allowedUDPPorts;
    "networking.firewall.interfaces" = config: config.networking.firewall.interfaces;

    # WireGuard
    "networking.wireguard.enable" = config: config.networking.wireguard.enable or false;
    "networking.wireguard.interfaces" =
      config:
      let
        wg = config.networking.wireguard.interfaces or {};
      in
      lib.mapAttrs
        (name: iface: {
          inherit (iface) ips listenPort;
          peers = map
            (p: {
              inherit (p) allowedIPs;
              publicKey = "<redacted>";
            })
            (iface.peers or []);
        })
        wg;

    # Tailscale
    "services.tailscale.enable" = config: config.services.tailscale.enable or false;
    "services.tailscale.useRoutingFeatures" = config: config.services.tailscale.useRoutingFeatures or null;
    "services.tailscale.extraSetFlags" = config: config.services.tailscale.extraSetFlags or [];
    "networking.tailscale.advertisedRoutes" = config: config.networking.tailscale.advertisedRoutes or [];

    # DNS/DHCP
    "services.dnsmasq.enable" = config: config.services.dnsmasq.enable or false;
    "services.dnsmasq.settings" = config: config.services.dnsmasq.settings or {};

    # Nginx
    "services.nginx.enable" = config: config.services.nginx.enable or false;
    "services.nginx.virtualHosts" =
      config:
      lib.mapAttrs
        (name: vhost: {
          inherit (vhost) enableACME forceSSL useACMEHost;
          listenAddresses = vhost.listenAddresses or [ ];
          locations = lib.mapAttrs
            (loc: locConf: {
              proxyPass = normalizePath locConf.proxyPass;
              root = if locConf ? root then normalizePath locConf.root else null;
              proxyWebsockets = locConf.proxyWebsockets or false;
            })
            (vhost.locations or { });
        })
        (config.services.nginx.virtualHosts or {});

    # Prometheus exporters
    "services.prometheus.exporters.node.enable" =
      config: config.services.prometheus.exporters.node.enable;
    "services.prometheus.exporters.node.port" = config: config.services.prometheus.exporters.node.port;
    "services.prometheus.exporters.dnsmasq.enable" =
      config: config.services.dnsmasq.enable;
    "services.prometheus.exporters.dnsmasq.port" =
      config: config.services.dnsmasq.port;

    # System
    "boot.kernel.sysctl" = config: config.boot.kernel.sysctl;
    "time.timeZone" = config: config.time.timeZone;
    "environment.systemPackages" =
      config: lib.unique (map (p: p.pname or p.name or "<unknown>") config.environment.systemPackages);

    # Services
    "systemd.services.tailscale-udp-gro.enable" =
      config: config.systemd.services.tailscale-udp-gro.enable or false;

    # ACME/Let's Encrypt
    "security.acme.defaults.email" = config: config.security.acme.defaults.email;
    "security.acme.certs" = config: builtins.attrNames config.security.acme.certs;
  };

  # Generate filtered JSON
  safeEval =
    name: getter:
    let
      result = builtins.tryEval (getter config);
    in
    if result.success then
      {
        inherit name;
        value = result.value;
      }
    else
      null;
  # Get all safe options
  evaluated = lib.filterAttrs (n: v: v != null) (
    lib.listToAttrs (
      map
        (
          name:
          let
            result = safeEval name safeOptions.${name};
          in
          if result != null then
            {
              inherit (result) name;
              value = result.value;
            }
          else
            {
              inherit name;
              value = null;
            }
        )
        (builtins.attrNames safeOptions)
    )
  );
in
evaluated // { machine = hostname; }