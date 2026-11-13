#!/usr/bin/env bash
# compare-configs.sh — thin wrapper preserving the documented interface.
# The tool itself lives in the Mayo golden tooling (lib/mayo/golden/compare-configs.sh).
exec nix run .#compare-configs -- "$@"
