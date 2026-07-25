# CI Configuration Module for NixOS Configuration Repository
# Generates GitHub Actions workflow from Nix evaluation
{ lib
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

  # Native aarch64 builds — evaluated on aarch64 runner
  armNativeMachines = [
    "display-1"
    "display-2"
    "print-controller"
  ];

  # Cross-compiled from x86_64 — evaluated on x86_64 runner, targets ARM
  armCrossMachines = [
    "arm-builder" # aarch64, buildPlatform=x86_64-linux
    "beta-one" # armv7l, buildPlatform=x86_64-linux
  ];

  # All ARM machines (for workflow_dispatch input)
  armMachines = armNativeMachines ++ armCrossMachines;

  # Pre-computed nix options per system type
  x86NixOptions = ciLib.formatNixOptions "x86-default" "x86_64-linux" parallelism;
  armNativeNixOptions = ciLib.formatNixOptions "arm-native" "aarch64-linux" parallelism;
  armCrossNixOptions = ciLib.formatNixOptions "arm-cross" "x86_64-linux" parallelism;

  # Pre-computed GitHub Actions max-parallel per system
  x86Settings = ciLib.resolveNixSettings "x86-default" "x86_64-linux" parallelism;
  armNativeSettings = ciLib.resolveNixSettings "arm-native" "aarch64-linux" parallelism;
  armCrossSettings = ciLib.resolveNixSettings "arm-cross" "x86_64-linux" parallelism;
  x86MaxParallel = x86Settings.max-parallel or null;
  armNativeMaxParallel = armNativeSettings.max-parallel or null;
  armCrossMaxParallel = armCrossSettings.max-parallel or null;

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

        # Eval profiler — generates flamegraph of flake evaluation
        # Diagnostic step: identifies eval bottlenecks (topology, module system, inputs)
        {
          name = "Profile evaluation";
          run = ''
            nix build --option eval-profiler flamegraph \
                      --option eval-profile-file /tmp/eval-profile \
                      --option builders "" \
                      .#nixosConfigurations.remote-builder.config.system.build.toplevel \
                      --dry-run 2>&1 || true
            if [ -f /tmp/eval-profile ]; then
              echo "=== Eval profile (top 20 stacks) ==="
              sort -rn -k2 /tmp/eval-profile | head -20
            fi
          '';
          "continue-on-error" = true;
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
      timeout-minutes = 720; # 12h — LINDA cold-cache builds take ~6h
    };

    # Build matrix for native ARM machines — evaluated on aarch64 runner
    build-arm-native = ciLib.mkMatrixJob {
      name = "Build ARM (native aarch64)";
      machines = armNativeMachines;
      system = "aarch64-linux";
      nixOptions = armNativeNixOptions;
      maxParallel = armNativeMaxParallel;
      needs = [ "validation" "security" ];
    };

    # Build matrix for cross-compiled ARM machines — evaluated on x86_64, targets ARM
    build-arm-cross = ciLib.mkMatrixJob {
      name = "Build ARM (cross-compiled from x86_64)";
      machines = armCrossMachines;
      system = "x86_64-linux";
      nixOptions = armCrossNixOptions;
      maxParallel = armCrossMaxParallel;
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
        "build-arm-native"
        "build-arm-cross"
      ];
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
          run = ''
            MACHINE="''${{ github.event.inputs.machine }}"
            ARM_NATIVE="display-1 display-2 print-controller"
            ARM_CROSS="arm-builder beta-one"

            if echo "$ARM_NATIVE" | grep -qw "$MACHINE"; then
              NIX_OPTS="${armNativeNixOptions}"
            elif echo "$ARM_CROSS" | grep -qw "$MACHINE"; then
              NIX_OPTS="${armCrossNixOptions}"
            else
              NIX_OPTS="${x86NixOptions}"
            fi
            nix build "$NIX_OPTS" ".#nixosConfigurations.$MACHINE.config.system.build.toplevel"
          '';
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
      ];
    };
  };

  # Assemble workflow using ketchup generator with Bargman-specific data
  generateGitHubActions = ciLib.generateGitHubActions {
    name = "NixOS CI/CD";
    on = {
      push = {
        branches = [ "main" ];
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
    concurrency = {
      group = "\${{ github.workflow }}-\${{ github.ref }}";
      "cancel-in-progress" = true;
    };
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
