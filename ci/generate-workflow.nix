# GitHub Actions Workflow Generator
# Generates .github/workflows/ci.yml from Nix evaluation
{ self, lib, pkgs, ... }:

let
  ci = import ../ci.nix { inherit self lib pkgs; };
  
  # Convert Nix attrset to YAML
  toYAML = obj: builtins.toJSON obj;
  
  # Generate workflow file
  workflow = ci.ci.github-actions;
  
  # Create Python script for JSON to YAML conversion
  json2yaml = pkgs.writeScriptBin "json2yaml" ''
    #!${pkgs.python3}/bin/python3
    import sys
    import json
    sys.path.append("${pkgs.python3Packages.pyyaml}/${pkgs.python3.sitePackages}")
    import yaml
    
    data = json.load(sys.stdin)
    print(yaml.dump(data, default_flow_style=False, sort_keys=False))
  '';
  
  # Create script to generate workflow
  generateScript = pkgs.writeShellApplication {
    name = "generate-ci-workflow";
    runtimeInputs = [ pkgs.nix json2yaml ];
    text = ''
      set -euo pipefail
      
      # Generate workflow from Nix evaluation and convert to YAML
      # Only stdout contains the JSON, stderr contains warnings (which we ignore)
      nix eval --json .#ci.ci.github-actions 2>/dev/null | json2yaml
    '';
  };
  
  # Validate workflow script
  validateScript = pkgs.writeShellApplication {
    name = "validate-ci-workflow";
    runtimeInputs = [ pkgs.yq ];
    text = ''
      set -euo pipefail
      
      echo "Validating GitHub Actions workflow..."
      
      if [ ! -f .github/workflows/ci.yml ]; then
        echo "❌ Workflow file not found. Run: nix run .#generate-ci-workflow > .github/workflows/ci.yml"
        exit 1
      fi
      
      # Validate YAML syntax
      yq -e . .github/workflows/ci.yml > /dev/null
      echo "✅ YAML syntax valid"
      
      # Check for required fields
      if yq -e '.name' .github/workflows/ci.yml > /dev/null && \
         yq -e '.on' .github/workflows/ci.yml > /dev/null && \
         yq -e '.jobs' .github/workflows/ci.yml > /dev/null; then
        echo "✅ Required fields present"
      else
        echo "❌ Missing required fields"
        exit 1
      fi
      
      echo ""
      echo "Workflow validation complete!"
      echo ""
      echo "To commit:"
      echo "  git add .github/workflows/ci.yml"
      echo "  git commit -m \"ci: add GitHub Actions workflow\""
    '';
  };

in
{
  # Scripts for CI management
  scripts = {
    generate-ci-workflow = generateScript;
    validate-ci-workflow = validateScript;
  };
  
  # The generated workflow content
  workflow = workflow;
  
  # Machine information for CI
  ci-info = {
    x86-machines = ci.ci.machines.x86;
    arm-machines = ci.ci.machines.arm;
    all-machines = ci.ci.machines.all;
    job-count = builtins.length ci.ci.machines.all;
  };
}