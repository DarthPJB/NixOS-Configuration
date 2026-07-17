# lib/ci_library.nix
# Ketchup — The open-source CI pipeline library.
#
# Exports all CI pipeline generators, job builders, nix settings helpers,
# validators, and serializers as a clean API. This is the boundary between
# the generic CI engine (Ketchup) and the proprietary machine configs
# (Secret-Sauce).
#
# Usage:
#   ketchup-ci = import ./lib/ci_library.nix { inherit lib pkgs; };
#   ketchup-ci.mkMatrixJob { machines = [...]; system = "x86_64-linux"; }
#   ketchup-ci.formatNixOptions "machine" "x86_64-linux" parallelism
#   ketchup-ci.generateGitHubActions { name, on, jobs, permissions }
{ lib, pkgs }:

let
  # --- Job builders (generic) ---

  # Build a matrix job for a list of machines.
  # Returns a job attrset suitable for GitHub Actions workflow.
  mkMatrixJob =
    { name
    , machines
    , system ? "x86_64-linux"
    , nixOptions ? ""
    , needs ? [ ]
    , runs-on ? "self-hosted"
    , fail-fast ? false
    }: {
      inherit name needs runs-on;
      strategy = {
        inherit fail-fast;
        matrix.machine = machines;
      };
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
        }
        {
          name = "Build configuration";
          run = "nix build ${nixOptions} .#nixosConfigurations.\${{ matrix.machine }}.config.system.build.toplevel";
        }
      ];
    };

  # --- Nix settings helpers (generic) ---

  # Resolve parallelism settings: perMachine > perSystem > default
  resolveNixSettings = machine: system: parallelism:
    let
      pm = parallelism.perMachine or { };
      ps = parallelism.perSystem or { };
      base = parallelism.default or { };
      merged = base // (ps.${system} or { }) // (pm.${machine} or { });
    in
    merged;

  # Format nix settings as --option flags for CLI injection.
  # Always includes --option builders '' per Prime Directive 17.
  formatNixOptions = machine: system: parallelism:
    let
      settings = resolveNixSettings machine system parallelism;
      maxJobs = settings.max-jobs or null;
      cores = settings.cores or null;
    in
    lib.concatStringsSep " " (lib.filter (s: s != "") [
      "--option builders ''"
      (if maxJobs != null then "--option max-jobs ${toString maxJobs}" else "")
      (if cores != null then "--option cores ${toString cores}" else "")
    ]);

  # --- Workflow generator (generic) ---

  # Assemble a GitHub Actions workflow struct from parts.
  generateGitHubActions =
    { name
    , on
    , jobs
    , permissions ? {
        contents = "read";
        deployments = "write";
      }
    }: {
      inherit name on permissions jobs;
    };

  # --- Serialization pipeline (generic) ---

  # Python script for JSON to YAML conversion via PyYAML.
  json2yaml = pkgs.writeScriptBin "json2yaml" ''
    #!${pkgs.python3}/bin/python3
    import sys
    import json
    sys.path.append("${pkgs.python3Packages.pyyaml}/${pkgs.python3.sitePackages}")
    import yaml

    data = json.load(sys.stdin)
    print(yaml.dump(data, default_flow_style=False, sort_keys=True))
  '';

  # Generate GitHub Actions workflow YAML from Nix evaluation.
  generateWorkflowScript = pkgs.writeShellApplication {
    name = "generate-ci-workflow";
    runtimeInputs = [
      pkgs.nix
      pkgs.jq
      json2yaml
    ];
    text = ''
      set -euo pipefail

      nix eval --json .#ci.ci.github-actions | jq '{name, on, permissions, jobs}' | json2yaml
    '';
  };

  # Validate a generated GitHub Actions workflow YAML file.
  validateWorkflowScript = pkgs.writeShellApplication {
    name = "validate-ci-workflow";
    runtimeInputs = [ pkgs.yq ];
    text = ''
      set -euo pipefail

      echo "Validating GitHub Actions workflow..."

      if [ ! -f .github/workflows/ci.yml ]; then
        echo "Workflow file not found. Run: nix run .#generate-ci-workflow > .github/workflows/ci.yml"
        exit 1
      fi

      # Validate YAML syntax
      ${lib.getExe pkgs.yq} -e . .github/workflows/ci.yml > /dev/null
      echo "YAML syntax valid"

      # Check for required fields
      if ${lib.getExe pkgs.yq} -e '.name' .github/workflows/ci.yml > /dev/null && \
         ${lib.getExe pkgs.yq} -e '.on' .github/workflows/ci.yml > /dev/null && \
         ${lib.getExe pkgs.yq} -e '.jobs' .github/workflows/ci.yml > /dev/null; then
        echo "Required fields present"
      else
        echo "Missing required fields"
        exit 1
      fi

      echo ""
      echo "Workflow validation complete!"
    '';
  };

in
{
  # Job builders
  inherit mkMatrixJob;

  # Nix settings helpers
  inherit resolveNixSettings formatNixOptions;

  # Workflow generator
  inherit generateGitHubActions;

  # Serialization pipeline
  inherit json2yaml generateWorkflowScript validateWorkflowScript;
}
