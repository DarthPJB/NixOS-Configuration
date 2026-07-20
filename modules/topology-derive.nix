# modules/topology-derive.nix
# Phase 5-1.3.1: Foundation module that reads JSON topology and derives NixOS config.
#
# Reads topology/<hostname>.json and derives:
#   - networking.interfaces.*.ipv4.addresses  (from coordinate entries)
#   - services.prometheus.exporters.*         (from exporters map)
#   - services.nginx.virtualHosts.*           (from vhosts map + default_response)
#
# Design principles:
#   - Uses normal Nix merging ONLY (NO mkForce/mkOverride).
#   - Lists concatenate, attrsets merge recursively.
#   - If no JSON file exists for this hostname -> produces no config (early return).
#   - Interfaces starting with "mac:" are skipped (imperatively-managed devices).
#   - Registry validation surfaces errors as build assertions.
#
# { config, lib, pkgs, self, ... }:
#   ^ self is accepted for WireGuard path resolution (dormant), not required for JSON paths.

{ config, lib, pkgs, self, ... }:

let
  inherit (builtins)
    fromJSON readFile pathExists match elemAt
    toString attrNames filter head tail genList length
    attrValues listToAttrs removeAttrs;

  inherit (lib)
    hasPrefix hasSuffix optional optionals mapAttrs mapAttrs'
    concatStringsSep nameValuePair splitString;

  # Read the hostname from the NixOS config (already set by hardware/user config).
  # The hostname MUST match the topology filename -- enforced by mkRegistry.nix
  # validator 1 (filename/hostname binding).
  hostname = config.networking.hostName;
  topologyFile = ../topology/${hostname}.json;
  hasTopology = pathExists topologyFile;
  topology = if hasTopology then fromJSON (readFile topologyFile) else null;

  # ── IP address helpers ──────────────────────────────────────

  # Convert (subnet, peer_id) -> IP address.
  # For subnet "10.88.128.0/24" and peer_id 1 -> "10.88.128.1"
  subnetPeerToIP = subnet: peer_id:
    let
      parts = splitString "/" subnet;
      ip = elemAt parts 0;                              # "10.88.128.0"
      octets = splitString "." ip;
      prefix = concatStringsSep "." (lib.init octets);  # "10.88.128"
    in
    "${prefix}.${toString peer_id}";

  # Extract prefix length from CIDR notation.
  # For "10.88.128.0/24" -> 24
  prefixLengthFromSubnet = subnet:
    let
      parts = splitString "/" subnet;
      maskStr = elemAt parts 1;
    in
    fromJSON maskStr;

  # ── Default exporter ports ────────────────────────────────
  defaultPorts = {
    node    = 9100;
    nvidia  = 9101;
    disk    = 9102;
    smartctl = 9633;
    dnsmasq = 3101;
    nextcloud = 3106;
    nginx   = 9113;
  };

  # ── Cross-machine registry validation ──────────────────────
  registry = import ../lib/topology/mkRegistry.nix { inherit lib; };
  registryErrors = registry.errors;
  registryWarnings = registry.warnings;

  # ── Coordinate processing ─────────────────────────────────
  # Filter out interfaces starting with "mac:" (imperatively-managed).
  realCoordinates = if hasTopology then
    filter (c: !hasPrefix "mac:" (c.interface or "")) (topology.coordinate or [ ])
  else [ ];

  # Build interface config from each coordinate entry.
  # Each produces: networking.interfaces.<iface>.ipv4.addresses
  #   = [ { address = ...; prefixLength = ...; } ]
  interfaceConfig = listToAttrs (map (c:
    let
      ip   = subnetPeerToIP c.subnet c.peer_id;
      mask = prefixLengthFromSubnet c.subnet;
    in
    nameValuePair c.interface {
      ipv4.addresses = [
        {
          address = ip;
          prefixLength = mask;
        }
      ];
    }
  ) realCoordinates);

  # ── First coordinate IP for listen addresses ──────────────
  firstIP = if realCoordinates != [ ]
    then subnetPeerToIP (head realCoordinates).subnet (head realCoordinates).peer_id
    else "0.0.0.0";

  # ── Exporter configuration ────────────────────────────────
  # Each exporter entry in topology.exporters becomes:
  #   services.prometheus.exporters.<name>
  #     = { enable = true; port = ...; listenAddress = ...; extra... }
  #
  # Supports per-entry overrides:
  #   - port: override the default port
  #   - listenAddress: override the default firstIP listen address
  #   - any other fields passed through as-is (e.g. leasesPath, dnsmasqListenAddress)
  exporterConfig = if hasTopology && topology ? exporters then
    mapAttrs' (name: settings:
      let
        port = settings.port or defaultPorts.${name} or 9100;
        addr = settings.listenAddress or firstIP;
        # Pass through all other exporter-specific options unchanged
        extra = removeAttrs settings [ "port" "listenAddress" ];
      in
      nameValuePair name ({
        enable = true;
        inherit port;
        listenAddress = addr;
      } // extra)
    ) topology.exporters
  else { };

  # ── Nginx virtual host configuration ─────────────────────

  # Build a single vhost entry from its (name, [entry]) pair.
  # Each vhost entry is a list; take the first element (Phase B).
  buildVhost = vhostName: entries:
    let
      entry = head entries;

      # Common to all vhost types
      forceSSL      = entry.forceSSL or false;
      isDefault     = entry.default or false;
      serverNameOpt = entry.server_name or null;

      # Vhost type detection
      isProxy      = entry ? proxy_to;
      isReturn     = entry ? return;
      isStatic     = entry ? static;
      # Location key: "~/" (regex prefix) when regex_prefix is true, "/" (exact) otherwise
      regexPrefix  = entry.regex_prefix or false;

      # ACME config from per-entry
      perEntryAcmeEnable = (entry.acme or { }).enable or false;
      perEntryAcmeHost   = (entry.acme or { }).host or null;

      # Global default ACME host (used for proxy vhosts sharing a wildcard cert).
      # Only applies to PROXY vhosts, not return/static vhosts.
      globalAcmeHost = if isProxy then (topology.acme_host or null) else null;

      # Effective useACMEHost:
      #   - If per-entry acme.host is set AND differs from vhost name, OR
      #     per-entry acme.host is set AND enableACME is NOT true (reference),
      #     use per-entry value.
      #   - If per-entry acme.host is set AND equals vhost name AND
      #     enableACME is true (self-managed cert), don't set useACMEHost.
      #   - If no per-entry acme and vhost is a proxy, use global acme_host.
      effectiveUseACMEHost =
        if perEntryAcmeHost != null then (
          if perEntryAcmeEnable && perEntryAcmeHost == vhostName then null
          else perEntryAcmeHost
        ) else globalAcmeHost;

      # addSSL for proxy vhosts using global ACME host (matching genNginx).
      # Per-entry acme.host does NOT auto-set addSSL (matches golden/baseline).
      addSSLProxy = isProxy && globalAcmeHost != null && perEntryAcmeHost == null;

      # enableACME only when explicitly set in per-entry
      enableACMEEffective = perEntryAcmeEnable;

      # Proxy headers — enabled by per-entry proxy_headers flag.
      # When true, adds standard reverse-proxy headers to the location.
      # The golden for some machines (e.g. cortex-alpha) expects these
      # per-location headers from the old genNginx generator.
      proxyHeadersVal = if entry.proxy_headers or false then ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
      '' else null;

      # Location key: regex prefix ("~/") or exact ("/")
      locKey = if isProxy && regexPrefix then "~/" else "/";

      # Location block -- varies by type
      locationExtraConfig = if proxyHeadersVal != null then
        { extraConfig = proxyHeadersVal; }
      else { };

      locations =
        # Return-type vhost (e.g., catch-all return "444")
        if isReturn then {
          "${locKey}" = { return = entry.return; };
        }
        # Proxy-type vhost: with proxyWebsockets, optional extraConfig, proxy_pass
        else if isProxy then {
          "${locKey}" = {
            proxyPass       = "http://${entry.proxy_to}";
            proxyWebsockets = true;
          } // locationExtraConfig;
        }
        # Static-type vhost (e.g., serve files from a root)
        # Resolve relative root paths (from JSON, relative to topology/ dir)
        # to absolute Nix paths so the serializer produces <path> not <eval-error>.
        # Formula: ./../topology + "/" + staticRoot = absolute path from module dir
        else if isStatic then
        let
          staticRoot = entry.static.root;
          absRoot = if hasPrefix "/" staticRoot
            then staticRoot
            else ./../topology + ("/${staticRoot}");
        in {
          "/" = { root = absRoot; };
        }
        else { };

      # Listen addresses per-vhost override (when entry has explicit listenAddresses)
      listenAddressesConfig = if entry ? listenAddresses then
        { listenAddresses = entry.listenAddresses; }
      else { };

      # Server name override (when vhost key differs from server_name)
      serverNameConfig = if serverNameOpt != null then
        { serverName = serverNameOpt; }
      else { };

      # ACME attributes
      acmeConfig = { }
        // (if enableACMEEffective then { enableACME = true; } else { })
        // (if effectiveUseACMEHost != null then { useACMEHost = effectiveUseACMEHost; } else { });

      # Proxy-specific attrset (addSSL when using global ACME host)
      extraProxyCfg = if addSSLProxy then { addSSL = true; } else { };

    in
    {
      ${vhostName} = { }
        // (if isDefault then { default = true; } else { })
        // { inherit locations forceSSL; }
        // extraProxyCfg
        // serverNameConfig
        // listenAddressesConfig
        // acmeConfig;
    };

  # Process all vhosts from topology into a flat attrset of vhost configs.
  vhostConfig = if hasTopology && topology ? vhosts && topology.vhosts != { } then
    lib.foldl' (acc: name:
      acc // buildVhost name topology.vhosts.${name}
    ) { } (attrNames topology.vhosts)
  else { };

  # Default response vhost (from top-level default_response field).
  # Only applies when there is NO explicit "_" vhost in vhosts,
  # to avoid conflicting return values.
  # Maps "404-or-drop" -> nginx return code "404".
  defaultResponseConfig = if hasTopology
    && topology ? default_response
    && topology.default_response != null
    && !(topology.vhosts or { } ? "_")
  then {
    "_" = {
      default = true;
      locations."/" = {
        return = if topology.default_response == "404-or-drop"
          then "404"
          else topology.default_response;
      };
    };
  }
  else { };

  # Combined nginx vhosts: default_response first, explicit vhosts override.
  nginxVhosts = defaultResponseConfig // vhostConfig;

  # Only enable nginx if we have any vhosts to serve.
  enableNginx = vhostConfig != { } || defaultResponseConfig != { };

  # ── WireGuard public key validation (dormant) ────────────
  # Reads the public_key_file path from topology and emits a warning
  # if the file is missing. Path is relative to repo root.
  pubkeyWarnings = if hasTopology && topology ? public_key_file then
    let
      pkf      = topology.public_key_file;
      fullPath = ../${pkf};
      exists   = pathExists fullPath;
    in
    optional (!exists)
      "Topology: public_key_file '${pkf}' not found at ${toString fullPath}"
  else [ ];

in
{
  # ── Options ──────────────────────────────────────────────
  options.topology.enable = lib.mkOption {
    type = lib.types.bool;
    default = hasTopology;
    defaultText = lib.literalExpression "hasTopology";
    description = ''
      Enable topology-derived configuration for this host.
      Defaults to true when topology/${hostname}.json exists.
      Set to false to disable topology config without deleting the JSON file.
    '';
  };

  # ── Config ──────────────────────────────────────────────
  # Only produces config when:
  #   1. topology/<hostname>.json exists on disk (hasTopology), AND
  #   2. topology.enable option is true (user may disable).
  config = lib.mkIf (hasTopology && config.topology.enable) {

    # ── G. Validation assertions ──────────────────────────
    # Surface ALL registry errors as build assertions.
    assertions = [
      {
        assertion = registryErrors == [ ];
        message = ''
          Topology validation errors for ${hostname}:
          ${concatStringsSep "\n  " registryErrors}
        '';
      }
    ];

    # Non-blocking warnings from registry + public key check
    warnings = registryWarnings ++ pubkeyWarnings;

    # ── B. Interfaces + Addresses ─────────────────────────
    # DISABLED: WireGuard/Tailscale interfaces are out-of-scope for PONR.
    # LAN interface addresses not present in goldens — enables in later phase.
    # networking.interfaces = interfaceConfig;

    # ── C. Exporters ──────────────────────────────────────
    services.prometheus.exporters = exporterConfig;

    # ── D + E. Nginx vhosts + default_response ───────────
    services.nginx = lib.mkIf enableNginx {
      enable = true;
      virtualHosts = nginxVhosts;
    };

    # Ensure nginx can read ACME certificates
    # (moved to top-level users option, outside services.nginx)
    users.users.nginx.extraGroups = lib.mkIf enableNginx [ "acme" ];

  }; # config
}
