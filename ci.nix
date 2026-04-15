# CI Configuration Module for NixOS Configuration Repository
# Generates GitHub Actions workflow from Nix evaluation
{ self, lib, pkgs, ... }:

let
  # Machine categories for CI matrix
  x86Machines = [
    "terminal-zero"
    "terminal-nx-01"
    "cortex-alpha"
    "local-nas"
    "alpha-one"
    "alpha-two"
    "alpha-three"
    "LINDA"
    "gaming-host-1"
    "remote-worker"
    "storage-array"
    "remote-builder"
    "local-worker"  # Added: missing machine
    "obs-box"       # Added: missing machine
  ];

  armMachines = [
    "display-0"
    "display-1"
    "display-2"
    "print-controller"
    "beta-one"      # Added: armv7l-linux machine
  ];

  # CI job definitions
  ciJobs = {
    # Validation jobs (run on all PRs)
    validation = {
      name = "Validation & Linting";
      runs-on = "ubuntu-latest";
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
        }
        {
          name = "Install Nix";
          uses = "DeterminateSystems/nix-installer-action@main";
        }
        {
          name = "Setup Magic Nix Cache";
          uses = "DeterminateSystems/magic-nix-cache-action@main";
        }
        {
          name = "Format check";
          run = "nix fmt -- --check .";
        }
        {
          name = "Flake check";
          run = "nix flake check";
        }
        {
          name = "Dead code check";
          run = "nix run .#deadnix";
        }
      ];
    };

    # Build matrix for x86_64 machines
    build-x86 = {
      needs = [ "validation" "security" ];  # Added: enforce job hierarchy
      name = "Build x86_64 Configurations";
      runs-on = "ubuntu-latest";
      strategy = {
        fail-fast = false;
        matrix = {
          machine = x86Machines;
        };
      };
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
        }
        {
          name = "Install Nix";
          uses = "DeterminateSystems/nix-installer-action@main";
        }
        {
          name = "Setup Magic Nix Cache";
          uses = "DeterminateSystems/magic-nix-cache-action@main";
        }
        {
          name = "Build configuration";
          run = "nixos-rebuild build --flake .#\${{ matrix.machine }}";
        }
        {
          name = "Upload build artifact";
          uses = "actions/upload-artifact@v4";
          "with" = {
            name = "\${{ matrix.machine }}-config";
            path = "result/";
            retention-days = "7";
          };
        }
      ];
    };

    # Build matrix for ARM machines
    build-arm = {
      needs = [ "validation" "security" ];  # Added: enforce job hierarchy
      name = "Build ARM Configurations";
      runs-on = "ubuntu-latest";
      strategy = {
        fail-fast = false;
        matrix = {
          machine = armMachines;
        };
      };
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
        }
        {
          name = "Install Nix";
          uses = "DeterminateSystems/nix-installer-action@main";
        }
        {
          name = "Setup Magic Nix Cache";
          uses = "DeterminateSystems/magic-nix-cache-action@main";
        }
        {
          name = "Build configuration";
          run = "nixos-rebuild build --flake .#\${{ matrix.machine }}";
        }
        {
          name = "Upload build artifact";
          uses = "actions/upload-artifact@v4";
          "with" = {
            name = "\${{ matrix.machine }}-config";
            path = "result/";
            retention-days = "7";
          };
        }
      ];
    };

    # Security scan
    security = {
      name = "Security Scan";
      runs-on = "ubuntu-latest";
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
          "with" = {
            fetch-depth = "0";  # Full history for secret scanning
          };
        }
        {
          name = "Install Nix";
          uses = "DeterminateSystems/nix-installer-action@main";
        }
        {
          name = "Install Gitleaks";
          run = "nix-shell -p gitleaks --run 'gitleaks version'";
        }
        {
          name = "Run Gitleaks secret scanning";
          run = "nix-shell -p gitleaks --run 'gitleaks detect --source . --verbose'";
        }
        {
          name = "Check for plaintext secrets in Nix files";
          run = ''
            echo "Checking for potential secrets in Nix files..."
            
            # Enhanced pattern matching
            PATTERNS="password|secret|key|token|api_key|apikey|access_key|private_key"
            EXCLUDES="secrix|public|pub|README|documentation|\.pub$|_pub$"
            
            if grep -rE "$PATTERNS" --include="*.nix" . | grep -vE "$EXCLUDES"; then
              echo "⚠️  Potential secrets found in Nix files"
              echo "Review the above matches manually"
              # Don't fail - just warn for now
            else
              echo "✅ No obvious secrets found in Nix files"
            fi
          '';
        }
        {
          name = "Validate secrix configuration";
          run = "nix run .#secrix -- --help";
        }
        {
          name = "Check for hardcoded IPs";
          run = ''
            echo "Checking for hardcoded IP addresses..."
            # Look for IP patterns but exclude documentation
            if grep -rE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" --include="*.nix" . | grep -v "10.88.127" | grep -v "127.0.0.1" | grep -v "documentation"; then
              echo "⚠️  Non-standard IP addresses found (excluding VPN range)"
            else
              echo "✅ IP addresses appear standard"
            fi
          '';
        }
      ];
    };

    # Deployment preparation (manual trigger)
    deploy-prep = {
      needs = [ "validation" "security" "build-x86" "build-arm" ];  # Added: full dependency chain
      name = "Deploy - \${{ github.event.inputs.machine }}";
      runs-on = "ubuntu-latest";
      "if" = "github.event_name == 'workflow_dispatch'";
      # REMOVED: strategy.matrix - build only selected machine
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
        }
        {
          name = "Install Nix";
          uses = "DeterminateSystems/nix-installer-action@main";
        }
        {
          name = "Setup Magic Nix Cache";
          uses = "DeterminateSystems/magic-nix-cache-action@main";
        }
        {
          name = "Build configuration";
          # CHANGED: Use selected machine from input
          run = "nixos-rebuild build --flake .#\${{ github.event.inputs.machine }}";
        }
        {
          name = "Test deployment";
          "if" = "github.event.inputs.action == 'test'";
          run = "nix run .#\${{ github.event.inputs.machine }}";
        }
        {
          name = "Deploy to machine";
          "if" = "github.event.inputs.action == 'deploy'";
          run = "nix run .#\${{ github.event.inputs.machine }} -- switch";
        }
        {
          name = "Upload deployment logs";
          "if" = "always()";  # Upload even if deployment fails
          uses = "actions/upload-artifact@v4";
          "with" = {
            name = "deploy-\${{ github.event.inputs.machine }}-logs";
            path = "/tmp/deploy-*.log";
            retention-days = "30";
          };
        }
      ];
    };
  };

  # Generate GitHub Actions YAML
  generateGitHubActions = {
    name = "NixOS CI/CD";
    on = {
      push = {
        branches = [ "main" "jb/ai/overlord-8" ];
        paths = [
          "**.nix"
          "flake.lock"
          ".github/workflows/**"
        ];
      };
      pull_request = {
        branches = [ "main" ];
        paths = [
          "**.nix"
          "flake.lock"
        ];
      };
      workflow_dispatch = {
        inputs = {
          machine = {
            description = "Machine to deploy";
            required = true;
            type = "choice";
            options = x86Machines ++ armMachines;
          };
          action = {
            description = "Deployment action";
            required = true;
            type = "choice";
            options = [ "build" "test" "deploy" ];
            default = "build";
          };
        };
      };
    };

    permissions = {
      contents = "read";
      deployments = "write";
    };

    jobs = ciJobs;
  };

in
{
  # Export CI configuration
  ci = {
    # GitHub Actions workflow
    github-actions = generateGitHubActions;
    
    # Machine lists for external use
    machines = {
      x86 = x86Machines;
      arm = armMachines;
      all = x86Machines ++ armMachines;
    };
    
    # Job definitions
    jobs = ciJobs;
  };
  
  # Helper functions for CI
  ciHelpers = {
    # Generate matrix for a specific machine type
    mkMatrix = machines: {
      inherit machines;
      include = map (machine: {
        inherit machine;
        system = if builtins.elem machine armMachines then "aarch64-linux" else "x86_64-linux";
      }) machines;
    };
    
    # Generate deployment command
    mkDeployCommand = machine: action:
      if action == "deploy" then
        "nix run .#${machine} -- switch"
      else if action == "test" then
        "nix run .#${machine}"
      else
        "nixos-rebuild build --flake .#${machine}";
  };
}