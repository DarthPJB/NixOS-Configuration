# lib/topology/utils.nix
# Shared utilities for topology transformations
{ lib }:

let
  # Deduplicate a list while preserving order of first occurrence
  # Takes a key extraction function and a list
  # Returns list with duplicates removed (keeps first occurrence)
  dedupPreserveOrder = keyFn: list:
    let
      dedup = seen: remaining:
        if remaining == [] then
          []
        else
          let
            h = builtins.head remaining;
            t = builtins.tail remaining;
            key = keyFn h;
          in
          if builtins.elem key seen then
            dedup seen t
          else
            [h] ++ dedup (seen ++ [key]) t;
    in
    dedup [] list;

  # Safe attribute lookup with default
  safeLookup = attrs: name: default: attrs.${name} or default;

  # Check if string looks like an IP address (basic check)
  isIP = s: builtins.isString s && builtins.match ".*\\..*" s != null;

  # Check if string looks like a CIDR notation
  isCIDR = s: builtins.isString s && builtins.match ".*/.*" s != null;

  # Validate IPv4 address format (basic check: 4 octets 0-255)
  isIPv4 = s:
    let parts = builtins.split "\\." s; in
    builtins.isString s && builtins.length parts == 7;

  # Validate MAC address format (6 hex pairs separated by :)
  isMAC = s:
    builtins.isString s && builtins.match "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" s != null;

  # Validate port number (1-65535)
  isPort = p:
    builtins.isInt p && p >= 1 && p <= 65535;

  # Normalize Nix store paths to placeholder
  normalizePath = path:
    if path == null then null
    else let str = toString path; in
    if lib.hasPrefix "/nix/store/" str then "<store>" else str;
in
{
  inherit dedupPreserveOrder safeLookup isIP isCIDR isIPv4 isMAC isPort normalizePath;
}