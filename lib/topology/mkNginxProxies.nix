# lib/topology/mkNginxProxies.nix
# Transforms topology nginx proxies into NixOS nginx virtualHosts
# Inspired by infrastructure-2/modules/proxy-host.nix pattern
{ lib }:

rec {
  # Default listen addresses for cortex-alpha
  defaultListenAddresses = [
    "10.88.128.1"
    "10.88.127.1"
  ];

  # Generate proxy headers config
  proxyHeaders = ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  '';

  # Websocket upgrade headers
  websocketHeaders = ''
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
  '';

  # Create a single virtualHost configuration
  mkProxyHost =
    {
      topology,
      hostname,
      proxyConfig,
    }:
    let
      # Support both old format (string = backend URL) and new format (attrset)
      isLegacyFormat = builtins.isString proxyConfig;
      backend = if isLegacyFormat then proxyConfig else proxyConfig.backend;
      forceSSL' = if isLegacyFormat then true else (proxyConfig.forceSSL or true);
      websockets = if isLegacyFormat then true else (proxyConfig.websockets or false);

      # ACME host - use wildcard cert from topology
      acmeHost = topology.nginx.acmeHost or topology.domain;

      # Listen addresses - can be overridden per-host
      listenAddrs =
        if isLegacyFormat then
          defaultListenAddresses
        else
          (proxyConfig.listenAddresses or defaultListenAddresses);

      # Build extraConfig based on features
      extraConfig = proxyHeaders + (if websockets then websocketHeaders else "");
    in
    {
      forceSSL = forceSSL';
      useACMEHost = acmeHost;
      listenAddresses = listenAddrs;
      locations."~/" = {
        proxyPass = backend;
        inherit extraConfig;
        proxyWebsockets = websockets;
      };
    };

  # Generate all virtualHosts from topology
  mkAllProxies =
    {
      topology,
      config ? { },
    }:
    let
      proxies = topology.nginx.proxies or { };
    in
    builtins.mapAttrs (
      hostname: proxyConfig: mkProxyHost { inherit topology hostname proxyConfig; }
    ) proxies;
}
