#!/usr/bin/env bash

set -euo pipefail

# Get all machines from flake
ALL_MACHINES=$(nix flake show . --json | jq -r '.nixosConfigurations | keys[]')

echo "Topology Coverage Report"
echo "========================"
echo

TOTAL=0
WITH_TOPOLOGY=0
WITH_GOLDEN=0
COVERED=0

for machine in $ALL_MACHINES; do
  TOTAL=$((TOTAL + 1))

  # Check topology
  HAS_TOPOLOGY=$(nix eval --json "import ./topology.nix {} | builtins.hasAttr \"$machine\"")
  if [ "$HAS_TOPOLOGY" = "true" ]; then
    TOPOLOGY_STATUS="✓"
    WITH_TOPOLOGY=$((WITH_TOPOLOGY + 1))
  else
    TOPOLOGY_STATUS="✗"
  fi

  # Check golden
  if [ -f "real-topology/golden/$machine.json" ]; then
    GOLDEN_STATUS="✓"
    WITH_GOLDEN=$((WITH_GOLDEN + 1))
  else
    GOLDEN_STATUS="✗"
  fi

  # Covered if both
  if [ "$HAS_TOPOLOGY" = "true" ] && [ "$GOLDEN_STATUS" = "✓" ]; then
    COVERED=$((COVERED + 1))
  fi

  echo "$machine: Topology $TOPOLOGY_STATUS, Golden $GOLDEN_STATUS"
done

echo
echo "Summary:"
echo "- Total machines: $TOTAL"
echo "- With topology: $WITH_TOPOLOGY"
echo "- With golden tests: $WITH_GOLDEN"
echo "- Fully covered: $COVERED"

if [ $TOTAL -gt 0 ]; then
  PERCENT=$((COVERED * 100 / TOTAL))
  echo "- Coverage: ${PERCENT}%"
else
  echo "- Coverage: 100%"
fi

echo
if [ $COVERED -eq $TOTAL ]; then
  echo "✓ All machines are fully covered!"
else
  echo "✗ Coverage incomplete. Missing entries:"
  for machine in $ALL_MACHINES; do
    HAS_TOPOLOGY=$(nix eval --json "import ./topology.nix | builtins.hasAttr \"$machine\"")
    HAS_GOLDEN=$([ -f "real-topology/golden/$machine.json" ] && echo "true" || echo "false")
    if [ "$HAS_TOPOLOGY" != "true" ] || [ "$HAS_GOLDEN" != "true" ]; then
      echo "  - $machine: topology=${HAS_TOPOLOGY}, golden=${HAS_GOLDEN}"
    fi
  done
fi