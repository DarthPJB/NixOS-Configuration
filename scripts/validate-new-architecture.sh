#!/usr/bin/env bash
# scripts/validate-new-architecture.sh
# Validates new architecture against golden test

set -e

REPO_DIR="/speed-storage/repo/DarthPJB/NixOS-Configuration"
TEST_FILE="$REPO_DIR/tests/test-new-architecture.nix"
GOLDEN_FILE="$REPO_DIR/real-topology/golden/cortex-alpha.json"
OUTPUT_FILE="/tmp/new-architecture-cortex-alpha.json"

echo "Evaluating new architecture config for cortex-alpha..."
nix eval --json --impure --show-trace --expr "(import $TEST_FILE { lib = import <nixpkgs/lib>; })" > "$OUTPUT_FILE"

echo "Comparing with golden test..."
if diff -u "$GOLDEN_FILE" "$OUTPUT_FILE"; then
    echo "PASS: New architecture matches golden test"
    exit 0
else
    echo "FAIL: Differences found"
    exit 1
fi