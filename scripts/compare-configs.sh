#!/usr/bin/env bash
# compare-configs.sh - Compare NixOS configuration between git revisions
#
# Usage:
#   ./scripts/compare-configs.sh <machine> [rev1] [rev2]
#
# Examples:
#   ./scripts/compare-configs.sh cortex-alpha main HEAD
#   ./scripts/compare-configs.sh cortex-alpha HEAD~5 HEAD
#   ./scripts/compare-configs.sh cortex-alpha  # compares working dir with golden

set -euo pipefail

MACHINE="${1:-cortex-alpha}"
REV1="${2:-}"
REV2="${3:-}"

# Serializer expression - inline so it works from any revision
SERIALIZER_EXPR='
let
  lib = (import <nixpkgs> {}).lib;

  # Global attrs to skip at any level
  globalSkip = [ "__functor" "override" "overrideDerivation" "extend" "passthru" ];

  # Safe sections to extract
  safeSections = [
    { path = [ "networking" "hostName" ]; skip = []; }
    { path = [ "networking" "hostId" ]; skip = []; }
    { path = [ "networking" "domain" ]; skip = []; }
    { path = [ "networking" "nameservers" ]; skip = []; }
    { path = [ "networking" "firewall" ]; skip = []; }
    { path = [ "networking" "nat" ]; skip = []; }
    { path = [ "networking" "nftables" ]; skip = [ "ruleset" ]; }
    { path = [ "networking" "interfaces" ]; skip = []; }
    { path = [ "networking" "wireguard" ]; skip = []; }
    { path = [ "networking" "tailscale" ]; skip = []; }
    { path = [ "services" "tailscale" ]; skip = []; }
    { path = [ "services" "dnsmasq" ]; skip = [ "servers" ]; }
    { path = [ "services" "nginx" ]; skip = [ "proxyCache" "proxyCachePath" "statusPage" ]; }
    { path = [ "services" "openssh" ]; skip = []; }
    { path = [ "services" "prometheus" ]; skip = []; }
    { path = [ "boot" "loader" ]; skip = []; }
    { path = [ "boot" "kernel" "sysctl" ]; skip = []; }
    { path = [ "boot" "supportedFilesystems" ]; skip = []; }
    { path = [ "time" "timeZone" ]; skip = []; }
    { path = [ "environment" "systemPackages" ]; skip = []; }
    { path = [ "systemd" "services" "tailscale-udp-gro" ]; skip = []; }
    { path = [ "security" "acme" ]; skip = []; }
  ];

  safeGet = config: path: default:
    let result = builtins.tryEval (lib.attrByPath path default config);
    in if result.success then result.value else default;

  serializeValue = depth: skip: value:
    if depth > 15 then "<max-depth>"
    else
      let forced = builtins.tryEval value;
      in if !forced.success then "<eval-error>"
      else let v = forced.value; in
      if builtins.isFunction v then "<function>"
      else if builtins.isAttrs v then
        if (v.type or "") == "derivation" then "<derivation:${v.name or "unnamed"}>"
        else
          let
            allSkip = globalSkip ++ skip;
            names = builtins.filter (n: !(builtins.elem n allSkip)) (builtins.attrNames v);
            serializeAttr = n:
              let attrResult = builtins.tryEval v.${n};
              in { name = n; value = if attrResult.success then serializeValue (depth + 1) [] attrResult.value else "<eval-error>"; };
          in builtins.listToAttrs (map serializeAttr names)
      else if builtins.isList v then map (serializeValue (depth + 1) []) v
      else if builtins.isString v then
        if lib.hasPrefix "/nix/store/" v then "<store>/${lib.last (lib.splitString "/" v)}" else v
      else if builtins.isInt v || builtins.isFloat v || builtins.isBool v || v == null then v
      else "<${builtins.typeOf v}>";

  extractSection = config: section:
    let value = safeGet config section.path null;
    in { name = lib.concatStringsSep "." section.path; value = serializeValue 0 section.skip value; };

  flake = builtins.getFlake (builtins.toString ./.);
  config = flake.nixosConfigurations."'"$MACHINE"'".config;
  sections = map (extractSection config) safeSections;
in
builtins.listToAttrs sections
'

echo "=== Comparing NixOS config for: $MACHINE ==="
echo ""

if [ -z "$REV1" ]; then
  # No revisions specified - just dump current config
  echo "Dumping current configuration..."
  nix eval --json --impure --expr "$SERIALIZER_EXPR" 2>/dev/null | nix shell nixpkgs#jq --command jq -S .
  exit 0
fi

# Create temp directory for worktrees
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Evaluating config at revision: $REV1"
git worktree add -q "$TMPDIR/rev1" "$REV1" 2>/dev/null || true
(cd "$TMPDIR/rev1" && nix eval --json --impure --expr "$SERIALIZER_EXPR" 2>/dev/null) > "$TMPDIR/config1.json" || echo "Failed to evaluate rev1"

echo "Evaluating config at revision: $REV2"
git worktree add -q "$TMPDIR/rev2" "$REV2" 2>/dev/null || true
(cd "$TMPDIR/rev2" && nix eval --json --impure --expr "$SERIALIZER_EXPR" 2>/dev/null) > "$TMPDIR/config2.json" || echo "Failed to evaluate rev2"

# Cleanup worktrees
git worktree remove "$TMPDIR/rev1" --force 2>/dev/null || true
git worktree remove "$TMPDIR/rev2" --force 2>/dev/null || true

echo ""
echo "=== Differences ==="
nix shell nixpkgs#jq --command diff -u "$TMPDIR/config1.json" "$TMPDIR/config2.json" || echo "No differences found"
