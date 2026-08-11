# GitHub Actions Workflow Generator — Wiring
# Imports ketchup library and Bargman-specific CI data.
# All logic lives in lib/ci_library.nix (Ketchup) and ci.nix (Secret-Sauce).
{ self, lib, pkgs, ciMachines ? { }, ... }:

let
  ciLib = import ../lib/ci_library.nix { inherit lib pkgs; };
  ci = import ../ci.nix { inherit lib pkgs; machines = ciMachines; };
in
{
  # Scripts for CI management (from ketchup library)
  scripts = {
    generate-ci-workflow = ciLib.generateWorkflowScript { };
    validate-ci-workflow = ciLib.validateWorkflowScript;
  };

  # The generated workflow content
  workflow = ci.ci.github-actions;

  # Machine information for CI
  ci-info = {
    x86-machines = ci.ci.machines.x86;
    arm-machines = ci.ci.machines.arm;
    all-machines = ci.ci.machines.all;
    job-count = builtins.length ci.ci.machines.all;
  };
}
