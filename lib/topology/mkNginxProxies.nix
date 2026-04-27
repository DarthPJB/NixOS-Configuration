/*
Purpose: Transform topology nginx proxies into NixOS nginx virtualHosts

Inputs:
- topology.nginx: nginx configuration including proxies, listenAddresses, acmeHost
- topology.lan.gateway: gateway IP for default listen addresses
- topology.hosts.cortex-alpha.ip: host IP for default listen addresses
- topology.domain: domain for ACME host

Output: NixOS services.nginx.virtualHosts config
*/

/*
# lib/topology/mkNginxProxies.nix
# Transforms topology nginx proxies into NixOS nginx virtualHosts
# Inspired by infrastructure-2/modules/proxy-host.nix pattern
*/
{ lib }:

topology:

let
  utils = import ./utils.nix { inherit lib; };
  inherit (utils) safeLookup;
in
rec {
  # Default listen addresses for cortex-alpha
  defaultListenAddresses = topology.nginx.listenAddresses or [
    topology.lan.gateway
    topology.hosts.cortex-alpha.ip
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
      acmeHost = safeLookup (topology.nginx or {}) "acmeHost" topology.domain;

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
      config ? { },
    }:
    let
      proxies = safeLookup (topology.nginx or {}) "proxies" { };
    in
    builtins.mapAttrs (
      hostname: proxyConfig: mkProxyHost { inherit hostname proxyConfig; }
    ) proxies;
}