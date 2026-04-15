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
  ];

  armMachines = [
    "display-0"
    "display-1"
    "display-2"
    "print-controller"
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
      ];
    };

    # Build matrix for ARM machines
    build-arm = {
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
        }
        {
          name = "Install Nix";
          uses = "DeterminateSystems/nix-installer-action@main";
        }
        {
          name = "Check for secrets";
          run = ''
            echo "Checking for potential secrets in code..."
            # Check for common secret patterns
            if grep -r "password\|secret\|key\|token" --include="*.nix" . | grep -v "secrix\|public\|pub\|README\|documentation"; then
              echo "⚠️  Potential secrets found in Nix files"
              exit 1
            fi
            echo "✅ No secrets found in Nix files"
          '';
        }
        {
          name = "Validate secrix configuration";
          run = "nix run .#secrix -- --help";
        }
      ];
    };

    # Deployment preparation (manual trigger)
    deploy-prep = {
      name = "Deployment Preparation";
      runs-on = "ubuntu-latest";
      "if" = "github.event_name == 'workflow_dispatch'";
      strategy = {
        matrix = {
          machine = x86Machines ++ armMachines;
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
          name = "Generate deployment script";
          run = ''
            echo "Deployment script for ''${{ matrix.machine }}"
            echo "nix run .#''${{ matrix.machine }} -- switch"
          '';
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