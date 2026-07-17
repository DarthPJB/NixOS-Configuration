# CI Configuration Module for NixOS Configuration Repository
# Generates GitHub Actions workflow from Nix evaluation
{ self
, lib
, pkgs
, parallelism ? { }
, ...
}:

let
  # Import ketchup CI library for generic functions
  ciLib = import ./lib/ci_library.nix { inherit lib pkgs; };

  # Machine categories for CI matrix
  x86Machines = [
    "terminal-zero"
    "terminal-nx-01"
    "cortex-alpha"
    "local-nas"
    "alpha-one"
    "alpha-three"
    "LINDA"
    "gaming-host-1"
    "remote-worker"
    "remote-builder"
  ];

  armMachines = [
    "arm-builder"
    "display-1"
    "display-2"
    "print-controller"
    "beta-one" # Added: armv7l-linux machine
  ];

  # Pre-computed nix options per system type
  x86NixOptions = ciLib.formatNixOptions "x86-default" "x86_64-linux" parallelism;
  armNixOptions = ciLib.formatNixOptions "arm-default" "aarch64-linux" parallelism;

  # Pre-computed GitHub Actions max-parallel per system
  x86Settings = ciLib.resolveNixSettings "x86-default" "x86_64-linux" parallelism;
  armSettings = ciLib.resolveNixSettings "arm-default" "aarch64-linux" parallelism;
  x86MaxParallel = x86Settings.max-parallel or null;
  armMaxParallel = armSettings.max-parallel or null;

  # CI job definitions
  ciJobs = {
    # Validation jobs (run on all PRs)
    # Uses self-hosted runner for private flake input access
    validation = {
      name = "Validation & Linting";
      runs-on = "self-hosted";
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
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
          run = "nix shell nixpkgs#deadnix -c deadnix .";
          "continue-on-error" = true;
        }
      ];
    };

    # Build matrix for x86_64 machines — all-at-once for shared derivation benefit
    build-x86 = ciLib.mkMatrixJob {
      name = "Build x86_64 Configurations";
      machines = x86Machines;
      system = "x86_64-linux";
      nixOptions = x86NixOptions;
      maxParallel = x86MaxParallel;
      needs = [ "validation" "security" ];
    };

    # Build matrix for ARM machines — constrained concurrency for RPi memory
    build-arm = ciLib.mkMatrixJob {
      name = "Build ARM Configurations";
      machines = armMachines;
      system = "aarch64-linux";
      nixOptions = armNixOptions;
      maxParallel = armMaxParallel;
      needs = [ "validation" "security" ];
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
            fetch-depth = "0"; # Full history for secret scanning
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
    # Uses self-hosted runner for private flake input access
    deploy-prep = {
      needs = [
        "validation"
        "security"
        "build-x86"
        "build-arm"
      ]; # Added: full dependency chain
      name = "Deploy - \${{ github.event.inputs.machine }}";
      runs-on = "self-hosted";
      "if" = "github.event_name == 'workflow_dispatch'";
      # REMOVED: strategy.matrix - build only selected machine
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
        }

        {
          name = "Build configuration";
          run = "MACHINE=\${{ github.event.inputs.machine }}\nARM_MACHINES=\"arm-builder display-1 display-2 print-controller beta-one\"\nif echo \"\$ARM_MACHINES\" | grep -qw \"\$MACHINE\"; then\n  NIX_OPTS=\"${armNixOptions}\"\nelse\n  NIX_OPTS=\"${x86NixOptions}\"\nfi\nnix build \$NIX_OPTS .#nixosConfigurations.\$MACHINE.config.system.build.toplevel";
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
          "if" = "always()"; # Upload even if deployment fails
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

  # Assemble workflow using ketchup generator with Bargman-specific data
  generateGitHubActions = ciLib.generateGitHubActions {
    name = "NixOS CI/CD";
    on = {
      push = {
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
            options = [
              "build"
              "test"
              "deploy"
            ];
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
}
