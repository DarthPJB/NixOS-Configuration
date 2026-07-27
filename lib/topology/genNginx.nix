{ lib }:
# genNginx: settings -> hostname -> NixOS services.nginx config
#
# Two-arg generator called by topology-derive.nix or enable-wg-topology.nix.
# Called as: (import ./genNginx.nix { inherit lib; }) settings hostname
#
# Supports paths (checked in order):
#   1. topology-direct (Phase 2+): if settings has `topology`, use shared
#      buildVhost.nix to produce full vhost config from topology JSON.
#      Replicates inline buildVhost logic (topology-derive.nix:135-276) exactly.
#   2. New schema: if settings has `vhosts` (partial, for tests/horizons)
#   3. Legacy: machines.${hostname} (from mkNginxSettings etc)
#
# Returns: { services.nginx = { enable, virtualHosts }; users.users.nginx.extraGroups; }
# or {} if no config exists for the host.
settings: hostname:
let
  # ── Topology-direct path (uses shared buildVhost) ────────────
  hasTopology = settings ? topology;

  topologyConfig =
    if !hasTopology then { } else
    let
      builder = import ./buildVhost.nix { inherit lib; };
      b = builder { topology = settings.topology; };
    in
    if b.enableNginx then
      {
        services.nginx = {
          enable = true;
          virtualHosts = b.nginxVhosts;
        };
        users.users.nginx.extraGroups = [ "acme" ];
      }
    else { };

  # ── New schema path (vhosts) ───────────────────────────────
  hasVhosts = settings ? vhosts;

  vhostsConfig =
    let
      vhosts = settings.vhosts or { };
    in
    lib.mapAttrs
      (_vhostName: entries:
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
      vhosts;

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
      mkProxyHost = _domain: proxyConfig:
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
      mkBaseHost = _domain: baseConfig:
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
if hasTopology then
  topologyConfig
else if hasVhosts then
  {
    services.nginx = {
      enable = true;
      virtualHosts = vhostsConfig;
    };
    users.users.nginx.extraGroups = [ "acme" ];
  }
else if machineSettings != null then
  legacyConfig
else
  { }
