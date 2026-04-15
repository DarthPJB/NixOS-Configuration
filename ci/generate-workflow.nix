# GitHub Actions Workflow Generator
# Generates .github/workflows/ci.yml from Nix evaluation
{ self, lib, pkgs, ... }:

let
  ci = import ../ci.nix { inherit self lib pkgs; };
  
  # Convert Nix attrset to YAML
  toYAML = obj: builtins.toJSON obj;
  
  # Generate workflow file
  workflow = ci.ci.github-actions;
  
  # Create script to generate workflow
  generateScript = pkgs.writeShellApplication {
    name = "generate-ci-workflow";
    runtimeInputs = [ pkgs.jq pkgs.nix ];
    text = ''
      set -euo pipefail
      
      echo "Generating GitHub Actions workflow..."
      
      # Create .github/workflows directory if it doesn't exist
      mkdir -p .github/workflows
      
      # Generate workflow from Nix evaluation
      # Note: This creates a JSON file that can be converted to YAML manually
      # or using online tools. For now, we'll create a formatted JSON file.
      nix eval --json .#ci.ci.github-actions | jq . > .github/workflows/ci.json
      
      echo "✅ Workflow generated at .github/workflows/ci.json"
      echo ""
      echo "Note: Generated as JSON. To convert to YAML:"
      echo "  - Use online JSON to YAML converter"
      echo "  - Or install yq: nix-shell -p yq"
      echo "  - Then run: yq -P .github/workflows/ci.json > .github/workflows/ci.yml"
      echo ""
      echo "Workflow includes:"
      echo "  - Validation & Linting"
      echo "  - Build matrix for x86_64 machines"
      echo "  - Build matrix for ARM machines"
      echo "  - Security scanning"
      echo "  - Manual deployment triggers"
      echo ""
      echo "To commit:"
      echo "  git add .github/workflows/ci.json"
      echo "  git commit -m \"ci: add GitHub Actions workflow\""
    '';
  };
  
  # Validate workflow script
  validateScript = pkgs.writeShellApplication {
    name = "validate-ci-workflow";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      set -euo pipefail
      
      echo "Validating GitHub Actions workflow..."
      
      if [ ! -f .github/workflows/ci.json ]; then
        echo "❌ Workflow file not found. Run generate-ci-workflow first."
        exit 1
      fi
      
      # Validate JSON syntax
      jq . .github/workflows/ci.json > /dev/null
      echo "✅ JSON syntax valid"
      
      # Check for required fields
      if jq -e '.name' .github/workflows/ci.json > /dev/null && \
         jq -e '.on' .github/workflows/ci.json > /dev/null && \
         jq -e '.jobs' .github/workflows/ci.json > /dev/null; then
        echo "✅ Required fields present"
      else
        echo "❌ Missing required fields"
        exit 1
      fi
      
      echo ""
      echo "Workflow validation complete!"
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