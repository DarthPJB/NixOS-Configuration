{ lib }:
# genNginx: settings -> hostname -> NixOS services.nginx config
# Replicates production mkNginxProxies.nix output: mkProxyHost + mkBaseHost + mkAllProxies.
# Must produce byte-identical virtualHosts to the production path.
settings: hostname:
let
  machineSettings = settings.machines.${hostname} or null;
in
if machineSettings == null then { } else
let
  s = machineSettings;

  # Proxy headers (shared by all proxy locations)
  proxyHeaders = ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  '';

  websocketHeaders = ''
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
  '';

  # Create a single proxy virtualHost — matches production mkProxyHost
  mkProxyHost = domain: proxyConfig:
    let
      isLegacyFormat = builtins.isString proxyConfig;
      backend = if isLegacyFormat then proxyConfig else proxyConfig.backend;
      forceSSL' = if isLegacyFormat then true else (proxyConfig.forceSSL or true);
      websockets = if isLegacyFormat then true else (proxyConfig.websockets or false);
      listenAddrs = if isLegacyFormat then s.defaultListenAddresses
                    else (proxyConfig.listenAddresses or s.defaultListenAddresses);
      extraConfig = proxyHeaders + (if websockets then websocketHeaders else "");
    in
    {
      addSSL = true;
      forceSSL = forceSSL';
      useACMEHost = s.acmeHost;
      listenAddresses = listenAddrs;
      locations."~/" = {
        proxyPass = backend;
        inherit extraConfig;
        proxyWebsockets = websockets;
      };
    };

  # Create a base virtualHost — matches production mkBaseHost
  mkBaseHost = domain: baseConfig:
    let
      enableACME' = baseConfig.enableACME or false;
      forceSSL' = baseConfig.forceSSL or false;
      useACMEHost' = baseConfig.useACMEHost or (if enableACME' then null else s.acmeHost);
      listenAddrs = baseConfig.listenAddresses or s.listenAddresses;
      default' = baseConfig.default or false;
      root' = if baseConfig ? root then baseConfig.root else null;
      locations = if baseConfig ? locations then baseConfig.locations else { "/" = { }; };
      locationsWithDefaults = lib.mapAttrs
        (path: loc:
          {
            proxyPass = null;
            proxyWebsockets = false;
            root = if path == "/" then root' else null;
          } // loc
        )
        locations;
    in
    {
      enableACME = enableACME';
      forceSSL = forceSSL';
      useACMEHost = useACMEHost';
      listenAddresses = listenAddrs;
      default = default';
      locations = locationsWithDefaults;
    };

  # Build all virtualHosts — matches production mkAllProxies
  proxyHosts = builtins.mapAttrs mkProxyHost s.proxies;
  baseHosts = builtins.mapAttrs mkBaseHost s.baseVhosts;
  allVirtualHosts = proxyHosts // baseHosts;
in
{
  services.nginx = {
    enable = true;
    virtualHosts = allVirtualHosts;
  };

  # Ensure nginx can read ACME certificates
  users.users.nginx.extraGroups = [ "acme" ];
}