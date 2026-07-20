{ lib }:
# genNginx: settings -> hostname -> NixOS services.nginx config
#
# Two-arg generator called by modules/core-router-topology.nix:50.
# Called as: (import ./genNginx.nix { inherit lib; }) settings hostname
#
# Supports two paths:
#   1. New schema: if settings has `vhostPlanes` (camelCase), produce per-subnet
#      vhost stanzas from the vhostPlanes attrset. Each vhost name maps to a list
#      of { subnet, reason, proxy_to? } entries. Proxy entries emit proxyPass;
#      static entries emit an empty locations."/" block.
#   2. Legacy schema: if settings has `machines.${hostname}`, produce virtualHosts
#      from the machine's nginx.proxies and nginx.baseVhosts (original logic from
#      production mkNginxProxies.nix). Must produce byte-identical virtualHosts to
#      the production path.
#
# Returns: { services.nginx = { enable, virtualHosts }; users.users.nginx.extraGroups; }
# or {} if no config exists for the host.
settings: hostname:
let
  # ── New schema path (vhostPlanes) ──────────────────────────
  hasVhostPlanes = settings ? vhostPlanes;

  vhostPlanesConfig =
    let
      vhostPlanes = settings.vhostPlanes or { };
    in
    lib.mapAttrs
      (vhostName: entries:
        let
          # Take the first entry (Phase B — one vhost per plane)
          entry = builtins.head entries;
        in
        if entry ? proxy_to then
          {
            locations."/" = {
              proxyPass = "http://${entry.proxy_to}";
            };
          }
        else
          {
            # Static vhost — empty locations block
            locations."/" = { };
          }
      )
      vhostPlanes;

  # ── Legacy path (machines.${hostname}) ─────────────────────
  machineSettings = settings.machines.${hostname} or null;

  legacyConfig =
    let
      s = machineSettings;
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
      mkProxyHost = domain: proxyConfig:
        let
          isLegacyFormat = builtins.isString proxyConfig;
          backend = if isLegacyFormat then proxyConfig else proxyConfig.backend;
          forceSSL' = if isLegacyFormat then true else (proxyConfig.forceSSL or true);
          websockets = if isLegacyFormat then true else (proxyConfig.websockets or false);
          listenAddrs =
            if isLegacyFormat then s.defaultListenAddresses
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
      proxyHosts = builtins.mapAttrs mkProxyHost s.proxies;
      baseHosts = builtins.mapAttrs mkBaseHost s.baseVhosts;
      allVirtualHosts = proxyHosts // baseHosts;
    in
    {
      services.nginx = {
        enable = true;
        virtualHosts = allVirtualHosts;
      };
      users.users.nginx.extraGroups = [ "acme" ];
    };
in
if hasVhostPlanes then
  {
    services.nginx = {
      enable = true;
      virtualHosts = vhostPlanesConfig;
    };
    users.users.nginx.extraGroups = [ "acme" ];
  }
else if machineSettings != null then
  legacyConfig
else
  { }