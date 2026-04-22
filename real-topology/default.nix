# real-topology/default.nix
# Central hub for network reality, golden generation, and filtering
{
  lib,
  self ? null,
  ...
}:
let
  # Comprehensive list of network-related options to capture in golden
  # Each option is wrapped in tryEval to handle any evaluation errors gracefully
  safeOptions = {
    # Basic identity
    "networking.hostName" = config: config.networking.hostName;
    "networking.hostId" = config: config.networking.hostId;

    # NAT and firewall
    "networking.nat.enable" = config: config.networking.nat.enable;
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
    "networking.wireguard.enable" = config: config.networking.wireguard.enable;
    "networking.wireguard.interfaces" =
      config:
      let
        wg = config.networking.wireguard.interfaces;
      in
      lib.mapAttrs (name: iface: {
        inherit (iface) ips listenPort;
        peers = map (p: {
          inherit (p) allowedIPs;
          publicKey = "<redacted>";
        }) iface.peers;
      }) wg;

    # Tailscale
    "services.tailscale.enable" = config: config.services.tailscale.enable;
    "services.tailscale.useRoutingFeatures" = config: config.services.tailscale.useRoutingFeatures;
    "services.tailscale.extraSetFlags" = config: config.services.tailscale.extraSetFlags;
    "networking.tailscale.advertisedRoutes" = config: config.networking.tailscale.advertisedRoutes;

    # DNS/DHCP
    "services.dnsmasq.enable" = config: config.services.dnsmasq.enable;
    "services.dnsmasq.settings" = config: config.services.dnsmasq.settings;

    # Nginx
    "services.nginx.enable" = config: config.services.nginx.enable;
    "services.nginx.virtualHosts" =
      config:
      let
        # Normalize nix store paths to just indicate "store path"
        normalizePath =
          path:
          if path == null then
            null
          else
            let
              str = toString path;
            in
            if lib.hasPrefix "/nix/store/" str then "<store>" else str;
      in
      lib.mapAttrs (name: vhost: {
        inherit (vhost) enableACME forceSSL useACMEHost;
        listenAddresses = vhost.listenAddresses or [ ];
        locations = lib.mapAttrs (loc: locConf: {
          proxyPass = normalizePath locConf.proxyPass;
          root = normalizePath locConf.root;
          proxyWebsockets = locConf.proxyWebsockets or false;
        }) (vhost.locations or { });
      }) config.services.nginx.virtualHosts;

    # Prometheus exporters
    "services.prometheus.exporters.node.enable" =
      config: config.services.prometheus.exporters.node.enable;
    "services.prometheus.exporters.node.port" = config: config.services.prometheus.exporters.node.port;
    "services.prometheus.exporters.dnsmasq.enable" =
      config: config.services.prometheus.exporters.dnsmasq.enable;
    "services.prometheus.exporters.dnsmasq.port" =
      config: config.services.prometheus.exporters.dnsmasq.port;

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

    # Additional Services
    "services.prometheus.enable" = config: config.services.prometheus.enable;
    "services.openldap.enable" = config: config.services.openldap.enable;
    "services.openssh.enable" = config: config.services.openssh.enable;
    "services.openssh.settings.PasswordAuthentication" =
      config: config.services.openssh.settings.PasswordAuthentication;

    # Boot Configuration
    "boot.loader.systemd-boot.enable" = config: config.boot.loader.systemd-boot.enable;
    "boot.loader.efi.canTouchEfiVariables" = config: config.boot.loader.efi.canTouchEfiVariables;
    "boot.supportedFilesystems" = config: lib.unique config.boot.supportedFilesystems;

    # System Information
    "system.stateVersion" = config: config.system.stateVersion;
    "nixpkgs.hostPlatform" = config: config.nixpkgs.hostPlatform;

    # Additional Networking
    "networking.domain" = config: config.networking.domain;
    "networking.nameservers" = config: config.networking.nameservers;
  };
in
{
  inherit safeOptions;

  # Generate filtered JSON for a machine's networking configuration
  generateGolden =
    machineName:
    let
      config = self.nixosConfigurations.${machineName}.config;
      # Safely evaluate each option, catching any errors
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
          map (
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
          ) (builtins.attrNames safeOptions)
        )
      );
    in
    evaluated // { machine = machineName; };
}
