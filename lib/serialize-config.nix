# lib/serialize-config.nix
# Serialize NixOS configuration sections for comparison between revisions
#
# IMPORTANT: We cannot safely serialize the ENTIRE config because:
# 1. Some options have lazy evaluation that fails when forced
# 2. The module system uses exceptions for missing attrs (not caught by tryEval)
# 3. Some sections contain circular references
#
# Instead, we define a comprehensive list of config sections that ARE safe to evaluate.
{ lib }:

let
  # Safe top-level sections to extract
  # Each entry is: { path = [...]; skip = [...]; }
  # skip = list of attr names to skip within that section
  safeSections = [
    # Core networking
    { path = [ "networking" "hostName" ]; skip = []; }
    { path = [ "networking" "hostId" ]; skip = []; }
    { path = [ "networking" "domain" ]; skip = []; }
    { path = [ "networking" "nameservers" ]; skip = []; }
    { path = [ "networking" "firewall" ]; skip = []; }
    { path = [ "networking" "nat" ]; skip = []; }
    { path = [ "networking" "nftables" ]; skip = [ "ruleset" ]; } # ruleset can be huge
    { path = [ "networking" "interfaces" ]; skip = []; }
    { path = [ "networking" "wireguard" ]; skip = []; }
    { path = [ "networking" "tailscale" ]; skip = []; }

    # Services - some have problematic sub-options
    { path = [ "services" "tailscale" ]; skip = []; }
    { path = [ "services" "dnsmasq" ]; skip = [ "servers" ]; }
    { path = [ "services" "nginx" ]; skip = [ "proxyCache" "proxyCachePath" "statusPage" ]; }
    { path = [ "services" "openssh" ]; skip = []; }
    { path = [ "services" "prometheus" ]; skip = []; }
    { path = [ "services" "openldap" ]; skip = []; }

    # Boot
    { path = [ "boot" "loader" ]; skip = []; }
    { path = [ "boot" "kernel" "sysctl" ]; skip = []; }
    { path = [ "boot" "supportedFilesystems" ]; skip = []; }

    # Time
    { path = [ "time" "timeZone" ]; skip = []; }

    # Environment - systemPackages list can be huge
    { path = [ "environment" "systemPackages" ]; skip = []; }

    # Systemd services (selected)
    { path = [ "systemd" "services" "tailscale-udp-gro" ]; skip = []; }

    # Security
    { path = [ "security" "acme" ]; skip = []; }
  ];

  # Safely get a nested attribute, returning default on error
  safeGet = config: path: default:
    let
      result = builtins.tryEval (
        lib.attrByPath path default config
      );
    in
    if result.success then result.value else default;

  # Global attrs to skip at any level
  globalSkip = [ "__functor" "override" "overrideDerivation" "extend" "passthru" ];

  # Serialize a value, handling special types
  # skip = additional attr names to skip at this level
  serializeValue = depth: skip: value:
    if depth > 15 then
      "<max-depth>"
    else
      let
        forced = builtins.tryEval value;
      in
      if !forced.success then
        "<eval-error>"
      else
        let v = forced.value; in
        if builtins.isFunction v then
          "<function>"
        else if builtins.isAttrs v then
          # Check for derivation
          if (v.type or "") == "derivation" then
            "<derivation:${v.name or "unnamed"}>"
          else
            # Regular attrset
            let
              allSkip = globalSkip ++ skip;
              names = builtins.filter (
                n: !(builtins.elem n allSkip)
              ) (builtins.attrNames v);
              serializeAttr = n:
                let
                  attrResult = builtins.tryEval v.${n};
                in
                {
                  name = n;
                  value = if attrResult.success then
                    serializeValue (depth + 1) [] attrResult.value
                  else
                    "<eval-error>";
                };
              serialized = map serializeAttr names;
            in
            builtins.listToAttrs serialized
        else if builtins.isList v then
          map (serializeValue (depth + 1) []) v
        else if builtins.isString v then
          # Normalize store paths
          if lib.hasPrefix "/nix/store/" v then
            let parts = lib.splitString "/" v; in
            "<store>/${lib.concatStringsSep "/" (lib.drop 3 parts)}"
          else v
        else if builtins.isInt v || builtins.isFloat v || builtins.isBool v || v == null then
          v
        else
          "<${builtins.typeOf v}>";

  # Extract a section from config
  extractSection = config: section:
    let
      value = safeGet config section.path null;
      serialized = serializeValue 0 section.skip value;
    in
    {
      name = lib.concatStringsSep "." section.path;
      value = serialized;
    };

in
{
  # Main entry point: serialize all safe sections
  serializeConfig = config:
    let
      sections = map (extractSection config) safeSections;
    in
    builtins.listToAttrs sections;

  # For debugging: list all safe sections
  listSections = map (s: lib.concatStringsSep "." s.path) safeSections;
}
