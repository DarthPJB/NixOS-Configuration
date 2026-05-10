#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="/speed-storage/repo/DarthPJB/NixOS-Configuration"
cd "$PROJECT_ROOT" || { echo "Unable to enter project root: $PROJECT_ROOT" >&2; exit 1; }

default_summary=()
failures=0

report() {
  local label="$1"
  local code="$2"
  if [ "$code" -eq 0 ]; then
    echo "   PASS: $label"
  else
    echo "   FAIL: $label"
    failures=$((failures + 1))
  fi
}

check_topology() {
  echo "1/4 topology.nix existence and parse"
  local topology_file="${PROJECT_ROOT}/topology.nix"
  if [ ! -f "$topology_file" ]; then
    echo "   FAIL: topology.nix is missing at $topology_file"
    failures=$((failures + 1))
    return
  fi

  if nix --option builders '' eval --json --expr 'import ./topology.nix { }' >/dev/null 2>&1; then
    echo "   PASS: topology.nix imported successfully"
  else
    echo "   FAIL: topology.nix failed to parse"
    failures=$((failures + 1))
  fi
}

check_transformers() {
  echo "2/4 transformer and generator files present"
  local files=(
    "${PROJECT_ROOT}/lib/topology/mkWireguardSettings.nix"
    "${PROJECT_ROOT}/lib/topology/genWireguard.nix"
  )
  for file in "${files[@]}"; do
    if [ -f "$file" ]; then
      echo "   PASS: $file exists"
    else
      echo "   FAIL: $file not found"
      failures=$((failures + 1))
    fi
  done
}

run_flake_check() {
  echo "3/4 nix flake check"
  if nix --option builders '' flake check; then
    echo "   PASS: nix flake check succeeded"
  else
    echo "   FAIL: nix flake check failed"
    failures=$((failures + 1))
  fi
}

run_golden_test() {
  echo "4/4 cortex-alpha golden test"
  if nix --option builders '' run .#check-network -- cortex-alpha; then
    echo "   PASS: cortex-alpha matches golden"
  else
    echo "   FAIL: cortex-alpha golden test failed"
    failures=$((failures + 1))
  fi
}

check_topology
check_transformers
run_flake_check
run_golden_test

if [ "$failures" -eq 0 ]; then
  echo "\nAll topology validation checks passed."
else
  echo "\n${failures} topology validation check(s) failed."
fi

exit "$failures"
