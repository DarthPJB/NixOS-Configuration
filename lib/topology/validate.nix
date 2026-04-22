# lib/topology/validate.nix
# Validates a topology attribute set according to predefined rules.
# Returns { valid = true/false; errors = [...]; warnings = [...]; }

{ lib }:

let
  inherit (builtins)
    isString
    isAttrs
    isList
    isInt
    elem
    length
    filter
    hasAttr
    ;
  inherit (lib)
    attrNames
    attrValues
    flatten
    unique
    ;

  # Helper: Check if string matches basic IP format (contains dots)
  isIP = s: isString s && builtins.match ".*\\..*" s != null;

  # Helper: Check if string matches basic CIDR (contains /)
  isCIDR = s: isString s && builtins.match ".*/.*" s != null;

  # Helper: Basic check if IP is within subnet (prefix match)
  # Assumes subnet is like "192.168.1.0/24"
  ipInSubnet =
    ip: subnet:
    let
      parts = builtins.split "/" subnet;
      prefix = builtins.head parts;
      mask = builtins.toInt (builtins.elemAt parts 1);
      prefixParts = builtins.split "\\." prefix;
      ipParts = builtins.split "\\." ip;
    in
    # Basic check: match up to mask/8 (for /24, first 3 octets)
    let
      maskOctets = mask / 8;
    in
    builtins.all (i: builtins.elemAt prefixParts i == builtins.elemAt ipParts i) (
      builtins.genList (x: x) maskOctets
    );

  # Helper: Check for duplicates in a list
  hasDuplicates =
    list:
    let
      uniques = unique list;
    in
    length uniques != length list;

  # Helper: Get duplicates from list
  getDuplicates =
    list:
    let
      counts = builtins.foldl' (
        acc: item:
        if hasAttr item acc then acc // { ${item} = acc.${item} + 1; } else acc // { ${item} = 1; }
      ) { } list;
    in
    filter (item: counts.${item} > 1) (attrNames counts);

  validateTopology =
    topology:
    let
      errors = [ ];
      warnings = [ ];

      # Domain validation
      domainErrors =
        if !isString topology.domain || topology.domain == "" then
          [ "domain must be a non-empty string" ]
        else
          [ ];

      # LAN validation
      lanErrors =
        if !hasAttr "lan" topology || !isAttrs topology.lan then
          [ "lan must be an attrset" ]
        else
          let
            subnetErrors =
              if !hasAttr "subnet" topology.lan || !isCIDR topology.lan.subnet then
                [ "lan.subnet must be valid CIDR notation" ]
              else
                [ ];

            gatewayErrors =
              if !hasAttr "gateway" topology.lan || !isIP topology.lan.gateway then
                [ "lan.gateway must be an IP address" ]
              else
                [ ];

            hostsErrors =
              if !hasAttr "hosts" topology.lan || !isAttrs topology.lan.hosts then
                [ "lan.hosts must be an attrset" ]
              else
                let
                  hostList = attrValues topology.lan.hosts;
                  hostErrors = flatten (
                    map (
                      host:
                      if !hasAttr "ip" host || !isIP host.ip then
                        [ "host ${host.name or "unnamed"} must have valid ip field" ]
                      else if hasAttr "subnet" topology.lan && !ipInSubnet host.ip topology.lan.subnet then
                        [ "host ${host.name or "unnamed"} IP ${host.ip} not within subnet ${topology.lan.subnet}" ]
                      else
                        [ ]
                    ) hostList
                  );

                  allIPs = map (h: h.ip) hostList;
                  duplicateIPErrors =
                    if hasDuplicates allIPs then map (dup: "duplicate IP: ${dup}") (getDuplicates allIPs) else [ ];

                  allMACs = filter (m: m != null) (map (h: h.mac or null) hostList);
                  duplicateMACErrors =
                    if hasDuplicates allMACs then map (dup: "duplicate MAC: ${dup}") (getDuplicates allMACs) else [ ];
                in
                hostErrors ++ duplicateIPErrors ++ duplicateMACErrors;
          in
          subnetErrors ++ gatewayErrors ++ hostsErrors;

      # Forwarding validation
      forwardingErrors =
        if !hasAttr "forwarding" topology || !isAttrs topology.forwarding then
          [ "forwarding must be an attrset" ]
        else
          let
            tcpErrors =
              if !hasAttr "tcp" topology.forwarding || !isList topology.forwarding.tcp then
                [ "forwarding.tcp must be a list" ]
              else
                flatten (
                  map (
                    rule:
                    if !hasAttr "port" rule || !hasAttr "dest" rule then
                      [ "forwarding.tcp rule must have port and dest fields" ]
                    else
                      [ ]
                  ) topology.forwarding.tcp
                );

            udpErrors =
              if !hasAttr "udp" topology.forwarding || !isList topology.forwarding.udp then
                [ "forwarding.udp must be a list" ]
              else
                flatten (
                  map (
                    rule:
                    if !hasAttr "port" rule || !hasAttr "dest" rule then
                      [ "forwarding.udp rule must have port and dest fields" ]
                    else
                      [ ]
                  ) topology.forwarding.udp
                );
          in
          tcpErrors ++ udpErrors;

      # DNS validation
      dnsErrors =
        if !hasAttr "dns" topology || !isAttrs topology.dns then
          [ "dns must be an attrset" ]
        else if !hasAttr "static" topology.dns || !isList topology.dns.static then
          [ "dns.static must be a list" ]
        else
          flatten (
            map (
              entry:
              if !isString entry || builtins.match "/.*/.*" entry == null then
                [ "dns.static entry '${entry}' must be in format '/domain/ip'" ]
              else
                [ ]
            ) topology.dns.static
          );

      # WireGuard validation
      wireguardErrors =
        if hasAttr "wireguard" topology && isAttrs topology.wireguard then
          if hasAttr "listenPort" topology.wireguard && !isInt topology.wireguard.listenPort then
            [ "wireguard.listenPort must be a number" ]
          else
            [ ]
        else
          [ ];

      # Firewall validation
      firewallErrors =
        if !hasAttr "firewall" topology || !isAttrs topology.firewall then
          [ "firewall must be an attrset" ]
        else
          let
            tcpPortsErrors =
              if !hasAttr "allowedTCPPorts" topology.firewall || !isList topology.firewall.allowedTCPPorts then
                [ "firewall.allowedTCPPorts must be a list" ]
              else
                [ ];

            udpPortsErrors =
              if !hasAttr "allowedUDPPorts" topology.firewall || !isList topology.firewall.allowedUDPPorts then
                [ "firewall.allowedUDPPorts must be a list" ]
              else
                [ ];
          in
          tcpPortsErrors ++ udpPortsErrors;

      # Combine all errors
      allErrors =
        domainErrors ++ lanErrors ++ forwardingErrors ++ dnsErrors ++ wireguardErrors ++ firewallErrors;

      # Warnings (none defined yet)
      allWarnings = warnings;

    in
    {
      valid = allErrors == [ ];
      errors = allErrors;
      warnings = allWarnings;
    };

in
{
  inherit validateTopology;
}
