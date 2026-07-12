{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    carmelsite = { url = "git+https://gitlab.com/mecha-team-zero/carmelsite.git"; };
    deadnix = { url = "github:astro/deadnix"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    hyprland.url = "github:hyprwm/Hyprland";
    lint-utils = { url = "github:homotopic/lint-utils"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    secrix.url = "github:Platonic-Systems/secrix";
    nixinate = { url = "github:Bargman-Tech/nixinate"; inputs.nixpkgs.follows = "nixpkgs_unstable"; };
    nixpkgs_stable.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs_unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0";
    nixpkgs_llm.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    hype-train-claw.url = "github:marijanp/zeroclaw";
    hype-train-outlaw.url = "git+https://gitlab.com/mecha-team-zero/macha-orchestration";
    star-citizen.url = "github:LovingMelody/nix-citizen";
    xlibre-overlay.url = "git+https://codeberg.org/takagemacoed/xlibre-overlay";
    ratty.url = "github:DarthPJB/ratty/fix/nix-module-improvements";
    ikbaeb-th = { url = "github:DarthPJB/IKBAEB-th"; };
    bargman-assets.url = "git+https://gitlab.com/mecha-team-zero/bargman-assets.git";
    denton-glasses.url = "git+https://gitlab.com/mecha-team-zero/denton-glasses.git";
    personal-site = { url = "git+https://gitlab.com/mecha-team-zero/bargman-website.git"; };
    # LLM-CORE: Disabled for overlord-I deployment — re-enable and test as part of overlord-II
    # LLM-CORE = { url = "git+https://gitlab.com/mecha-team-zero/llm-core.git"; };
  };
  # LLM-CORE: Disabled for overlord-I deployment — re-enable and test as part of overlord-II
  outputs = { self, deadnix, determinate, hyprland, lint-utils, nixinate, nixos-hardware, nixpkgs_stable, nixpkgs_unstable, nixpkgs_llm, hype-train-outlaw, star-citizen, parsecgaming, secrix, hype-train-claw, carmelsite, xlibre-overlay, ratty, ikbaeb-th, bargman-assets, denton-glasses, personal-site/*, LLM-CORE*/ }:
    let
      nixpkgs = nixpkgs_stable.legacyPackages.x86_64-linux;
      lib = nixpkgs_stable.lib;
      # Import topology to derive deployment IPs from single source of truth
      topo = import ./topology/shared.nix { inherit lib; };
      # Get wireguard IP for a machine from topology
      topoIp = machineName: topo.${machineName}.wireguard;
      globalArgs = {
        inherit self;
        inherit ikbaeb-th;
        inherit bargman-assets;
        inherit denton-glasses;
        inherit personal-site;
        # inherit LLM-CORE;  # Disabled for overlord-I — re-enable as part of overlord-II
        pkgs_llm = import nixpkgs_llm { system = "x86_64-linux"; config.allowUnfree = true; config.permittedInsecurePackages = [ "nodejs-20.20.2" "nodejs-slim-20.20.2" ]; };
      };
      minecraft-curseforge-builder = nixpkgs.callPackage ./pkgs/minecraft-curseforge { };
      prometheus-mcp-server-builder = nixpkgs.callPackage ./pkgs/prometheus-mcp-server { };
      commonModules = [
        secrix.nixosModules.default
        ratty.nixosModules.default
        ./configuration.nix
        {
          programs.ssh.knownHosts = mkKnownHosts self.nixosConfigurations;
          programs.ssh.extraConfig = ''
            # Fleet-wide SSH multiplexing
            Host *
              ControlMaster auto
              ControlPath /run/ssh-mux/%r@%h:%p
              ControlPersist 15m
          '';
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [
            ratty.overlays.default
            (final: prev: {
              minecraft-curseforge = minecraft-curseforge-builder;
              prometheus-mcp-server = prometheus-mcp-server-builder;
              # minecraft-curseforge-atm10 = self.packages.x86_64-linux.minecraft-curseforge-atm10;
              # minecraft-curseforge-atm10-to-the-sky = self.packages.x86_64-linux.minecraft-curseforge-atm10-to-the-sky;
              minecraft-curseforge-all-the-mons = self.packages.x86_64-linux.minecraft-curseforge-all-the-mons;
              squaremap-neoforge = self.packages.x86_64-linux.squaremap-neoforge;
            })
          ];
          system.stateVersion = "25.11";
          secrix.defaultEncryptKeys.John88 = [
            (builtins.readFile ./secrets/public_keys/JOHN_BARGMAN_ED_25519.pub) # Four years ago matthew croughan said "why bother putting that there?" so... This is why.
          ];
          # SSH multiplexing socket directory
          systemd.tmpfiles.rules = [
            "d /run/ssh-mux 0755 root root"
          ];
        }
      ];
      mkX86_64 = hostname: { extraModules ? [ ], hostPubKey ? builtins.readFile ./secrets/public_keys/host_keys/${hostname}.pub, host ? null, sshUser ? "deploy", buildOn ? "local", dt ? true, sshPort ? 1108 }:
        nixpkgs_stable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = commonModules ++ extraModules ++ (if dt then [ determinate.nixosModules.default ] else [ ]) ++ [
            ./machines/${hostname}
            {
              boot.kernelPatches = lib.singleton {
                name = "disable-backdoor";
                patch = null;
                features.rust = false;
              };

              nixpkgs.hostPlatform = "x86_64-linux";
              nix.registry.nixpkgs.flake = nixpkgs_stable;
              networking.hostName = hostname;
              secrix.hostPubKey = if hostPubKey != null then hostPubKey else null;
              _module.args = globalArgs // {
                inherit hostname;
                unstable = import nixpkgs_unstable { system = "x86_64-linux"; config.allowUnfree = true; };
                nixinate = {
                  inherit host sshUser buildOn;
                  port = sshPort;
                };
              };
            }
          ];
        };
      mkAarch64 = hostname: { extraModules ? [ ], hostPubKey ? builtins.readFile ./secrets/public_keys/host_keys/${hostname}.pub, host ? null, sshUser ? "deploy", buildOn ? "local", dt ? false, hardware ? nixos-hardware.nixosModules.raspberry-pi-4 }:
        nixpkgs_unstable.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${nixpkgs_unstable}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            "${nixpkgs_unstable}/nixos/modules/profiles/minimal.nix"
            hardware
          ] ++ commonModules ++ extraModules ++ (if dt then [ determinate.nixosModules.default ] else [ ]) ++ [
            ./machines/${hostname}
            {
              nixpkgs.overlays = [
                (final: super: {
                  makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
                })
              ];
              nixpkgs.hostPlatform = "aarch64-linux";
              networking.hostName = hostname;
              secrix.hostPubKey = if hostPubKey != null then hostPubKey else null;
              documentation = { dev.enable = false; man.enable = false; info.enable = false; enable = false; };
              disabledModules = [
                "profiles/all-hardware.nix"
                "profiles/base.nix"
              ];
              _module.args = globalArgs // {
                inherit hostname;
                unstable = import nixpkgs_unstable { system = "aarch64-linux"; config.allowUnfree = true; };
                nixinate = {
                  inherit host sshUser;
                  buildOn = "local";
                  port = 1108;
                };
              };
            }
          ];
        };
      mkLibVirtImage = { config, name, format ? "qcow2", partitionTableType ? "efi", installBootLoader ? true, touchEFIVars ? true, diskSize ? "auto", additionalSpace ? "2048M", copyChannel ? true }:
        import "${nixpkgs_stable}/nixos/lib/make-disk-image.nix" {
          pkgs = nixpkgs_stable.legacyPackages.x86_64-linux;
          lib = nixpkgs_stable.lib;
          inherit config name format partitionTableType installBootLoader touchEFIVars diskSize additionalSpace copyChannel;
        };
      mkUncompressedSdImage = config:
        (config.extendModules {
          modules = [{ sdImage.compressImage = false; }];
        }).config.system.build.sdImage;
      mkUncompressedSdImages = configs:
        nixpkgs_stable.lib.genAttrs
          (map (cfg: cfg.config.system.name) configs)
          (name: mkUncompressedSdImage (builtins.getAttr name self.nixosConfigurations));

      mkKnownHosts = nixosConfigs:
        let
          # Combine active and dormant configs for key lookup
          allConfigs = nixosConfigs // (self.dormantConfigurations or { });

          # Get public key: secrix first, file fallback second
          getPubKey = name:
            let
              fromConfig = allConfigs.${name}.config.secrix.hostPubKey or null;
              fromFile =
                let p = ./secrets/public_keys/host_keys/${name}.pub;
                in if builtins.pathExists p then builtins.readFile p else null;
            in
            if fromConfig != null then fromConfig else fromFile;

          # Build hostNames from topology: hostname + domain + all known IP routes
          getHostNames = name:
            let
              entry = topo.${name} or null;
              names = [ name "${name}.johnbargman.net" ];
            in
            if entry != null then
              lib.unique
                (names
                  ++ lib.optionals (entry ? wireguard) [ entry.wireguard ]
                  ++ lib.optionals (entry ? lan) (builtins.attrNames entry.lan)
                  ++ lib.optionals (entry ? uplink) (builtins.attrNames entry.uplink)
                )
            else
              names;

          # Union of all known machines: topology + active configs + dormant configs
          allMachines = lib.unique (
            builtins.attrNames topo
            ++ builtins.attrNames nixosConfigs
            ++ builtins.attrNames (self.dormantConfigurations or { })
          );

          # Build entries, skipping machines without a known key
          entries = builtins.listToAttrs (map
            (name:
              let
                pubKey = getPubKey name;
              in
              lib.nameValuePair name (
                if pubKey != null then {
                  hostNames = getHostNames name;
                  publicKey = pubKey;
                } else null
              )
            )
            allMachines);
        in
        lib.filterAttrs (name: value: value != null) entries;

      # CI/CD Configuration
      ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; };

      # CI Generator Scripts
      ci-generator = import ./ci/generate-workflow.nix { inherit self lib; pkgs = nixpkgs; };
    in
    {
      formatter."x86_64-linux" = nixpkgs.nixpkgs-fmt;
      apps."x86_64-linux" = { secrix = secrix.secrix self; } // (nixinate.lib.genDeploy.x86_64-linux self) // {
        # Check network config against golden
        check-network = {
          type = "app";
          meta.description = "Check network config against golden file";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "check-network";
            runtimeInputs = [ nixpkgs.jq ];
            text = ''
              MACHINE="''${1:-cortex-alpha}"
              echo "Checking network config for $MACHINE..."
              nix run .#dump-config -- "$MACHINE" | jq -S . > /tmp/current-network.json
                
              if diff -u "${self}/goldens/$MACHINE.json" /tmp/current-network.json; then
                echo "✓ Network config matches golden for $MACHINE"
              else
                echo "✗ Network configuration has changed from golden!"
                echo "If intentional, update with:"
                echo "  nix run .#dump-config -- $MACHINE > goldens/$MACHINE.json"
                exit 1
              fi
            '';
          });
        };

        # Full config serialization for comparing between revisions
        dump-config = {
          type = "app";
          meta.description = "Dump full NixOS config to JSON (for comparing between git revisions)";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "dump-config";
            runtimeInputs = [ nixpkgs.jq ];
            text = ''
              if [ -z "$1" ]; then
                echo "Usage: nix run .#dump-config <machine-name>"
                echo "Example: nix run .#dump-config cortex-alpha > /tmp/config.json"
                echo ""
                echo "To compare between revisions:"
                echo "  git checkout old-rev && nix run .#dump-config cortex-alpha > /tmp/old.json"
                echo "  git checkout new-rev && nix run .#dump-config cortex-alpha > /tmp/new.json"
                echo "  diff /tmp/old.json /tmp/new.json"
                exit 1
              fi
              MACHINE="$1"
              nix eval --json --impure \
                --expr '
                  let
                    flake = builtins.getFlake (builtins.toString ./.);
                    lib = (import <nixpkgs> {}).lib;
                    serializer = import ./lib/serialize-config.nix { inherit lib; };
                    config = flake.nixosConfigurations."'"$MACHINE"'".config;
                  in
                  serializer.serializeConfig config
                ' | jq -S .
            '';
          });
        };

        deploy-all = {
          type = "app";
          meta.description = "itsa make the pizza delivery";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "deploy-all";
            runtimeInputs = with nixpkgs; [ nix jq figlet ];
            text = ''
               set -euo pipefail

              CONFIGS=$(nix flake show --json . | jq -r '.nixosConfigurations | keys[]' )

               if [ -z "$CONFIGS" ]; then
                 figlet "No deployable configurations found."
                 exit 1
               fi

               ARG="$1"

               figlet "Deploying to all hosts..."
               for config in $CONFIGS; do 
                 echo "------------------- Deploying $config -------------------"
                 nix run ".#$config" -- "$ARG" || figlet "$config HAS FAILED!!"
               done

               echo "All deployments finished."
            '';
          });
        };
        build-all = {
          type = "app";
          meta.description = "itsa make the pizzaz early";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "build-all";
            runtimeInputs = with nixpkgs; [ nix jq figlet ];
            text = ''
              set -euo pipefail

              CONFIGS=$(nix flake show --json . | jq -r '.nixosConfigurations | keys[]' )

              if [ -z "$CONFIGS" ]; then
                figlet "No deployable configurations found."
                exit 1
              fi

              figlet "Building all hostnames"
              for config in $CONFIGS; do 
                echo "------------------- Deploying $config -------------------"
                nixos-rebuild build --flake ".#$config" || figlet "$config HAS FAILED!!"
              done

              echo "All deployments finished."
            '';
          });
        };
        generate-ci-workflow = {
          type = "app";
          meta.description = "Generate GitHub Actions workflow from Nix evaluation";
          program = "${ci-generator.scripts.generate-ci-workflow}/bin/generate-ci-workflow";
        };
        validate-ci-workflow = {
          type = "app";
          meta.description = "Validate GitHub Actions workflow";
          program = "${ci-generator.scripts.validate-ci-workflow}/bin/validate-ci-workflow";
        };
        ci = {
          type = "app";
          meta.description = "Show CI configuration info (machines, jobs, workflow status)";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "ci-info";
            runtimeInputs = with nixpkgs; [ jq ];
            text = ''
              echo "=== NixOS CI/CD Configuration ==="
              echo ""
              echo "x86_64 machines (${toString (builtins.length ci.ci.machines.x86)}):"
              printf '${lib.concatMapStrings (m: "  - ${m}\\n") ci.ci.machines.x86}'
              echo ""
              echo "ARM machines (${toString (builtins.length ci.ci.machines.arm)}):"
              printf '${lib.concatMapStrings (m: "  - ${m}\\n") ci.ci.machines.arm}'
              echo ""
              echo "Total machines: ${toString (builtins.length ci.ci.machines.all)}"
              echo ""
              echo "Jobs defined: ${toString (builtins.length (builtins.attrNames ci.ci.jobs))}"
              printf '${lib.concatMapStrings (j: "  - ${j}\\n") (builtins.attrNames ci.ci.jobs)}'
              echo ""
              echo "Workflow file: .github/workflows/ci.yml"
              if [ -f .github/workflows/ci.yml ]; then
                echo "Status: present"
              else
                echo "Status: MISSING (run: nix run .#generate-ci-workflow > .github/workflows/ci.yml)"
              fi
            '';
          });
        };
        bargman-greeter-vm = {
          type = "app";
          program = "${self.nixosConfigurations.bargman-greeter-vm.config.system.build.vm}/bin/run-bargman-greeter-vm-vm";
        };
        bargman-greeter-vm-serial = {
          type = "app";
          program = toString (
            nixpkgs.writeShellScript "run-bargman-greeter-vm-serial" ''
              export QEMU_OPTS="-display none -serial mon:stdio ''${QEMU_OPTS:-}"
              exec ${self.nixosConfigurations.bargman-greeter-vm.config.system.build.vm}/bin/run-bargman-greeter-vm-vm "$@"
            ''
          );
        };
      };

      packages = {
        "x86_64-linux" = {
          lightdm-webkit2-greeter = nixpkgs.callPackage ./pkgs/lightdm-webkit2-greeter.nix { };
          # minecraft-curseforge-atm10 = nixpkgs.callPackage ./pkgs/minecraft-curseforge/packs/atm10.nix {
          #   minecraft-curseforge = minecraft-curseforge-builder;
          # };
          # minecraft-curseforge-atm10-to-the-sky = nixpkgs.callPackage ./pkgs/minecraft-curseforge/packs/atm10-to-the-sky.nix {
          #   minecraft-curseforge = minecraft-curseforge-builder;
          # };
          minecraft-curseforge-all-the-mons = nixpkgs.callPackage ./pkgs/minecraft-curseforge/packs/all-the-mons.nix {
            minecraft-curseforge = minecraft-curseforge-builder;
          };
          squaremap-neoforge = nixpkgs.callPackage ./pkgs/minecraft-curseforge/squaremap.nix { };
          bargman-greeter-vm = self.nixosConfigurations.bargman-greeter-vm.config.system.build.vm;
          bargman-greeter-vm-bootloader = self.nixosConfigurations.bargman-greeter-vm.config.system.build.vmWithBootLoader;
        };
        "aarch64-linux" = mkUncompressedSdImages [
          self.nixosConfigurations.print-controller
          self.nixosConfigurations.display-1
          self.nixosConfigurations.arm-builder
          self.nixosConfigurations.arm-bootstrap
        ];
        "armv7l-linux" = mkUncompressedSdImages [
          self.nixosConfigurations.beta-one
        ];
      };

      nixosConfigurations = {
        beta-one = nixpkgs_unstable.lib.nixosSystem {
          system = "armv7l-linux";
          modules = [
            "${nixpkgs_unstable}/nixos/modules/installer/sd-card/sd-image-armv7l-multiplatform.nix"
            "${nixpkgs_unstable}/nixos/modules/profiles/minimal.nix"
            ./machines/beta/1.nix
            {
              _module.args = globalArgs // { hostname = "beta-one"; };
            }
          ];
        };

        display-1 = mkAarch64 "display-1" {
          host = topoIp "display-1";
          extraModules = [ ./users/build.nix ];
        };
        display-2 = mkAarch64 "display-2" {
          host = topoIp "display-2";
          extraModules = [ ./users/build.nix ];
        };
        arm-builder = mkAarch64 "arm-builder" {
          host = topoIp "arm-builder";
          extraModules = [
            ./users/deployment.nix
            ./users/build.nix
          ];
        };
        # Generic ARM bootstrap image — reusable for ALL ARM devices
        # No WG, no device-specific config, open SSH on port 22
        arm-bootstrap = nixpkgs_unstable.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${nixpkgs_unstable}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            "${nixpkgs_unstable}/nixos/modules/profiles/minimal.nix"
            nixos-hardware.nixosModules.raspberry-pi-4
            secrix.nixosModules.default
            ./machines/arm-bootstrap
            {
              nixpkgs.overlays = [
                (final: super: {
                  makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
                })
              ];
              nixpkgs.hostPlatform = "aarch64-linux";
              networking.hostName = "arm-bootstrap";
              _module.args = globalArgs // {
                hostname = "arm-bootstrap";
                unstable = import nixpkgs_unstable { system = "aarch64-linux"; config.allowUnfree = true; };
              };
            }
          ];
        };
        print-controller = mkAarch64 "print-controller" {
          host = topoIp "print-controller";
          hardware = nixos-hardware.nixosModules.raspberry-pi-3;
          extraModules = [ ./server_services/klipper.nix ];
        };

        terminal-zero = mkX86_64 "terminal-zero" {
          host = topoIp "terminal-zero";
          extraModules = [
            ./modifier_imports/central-builder.nix
            nixos-hardware.nixosModules.lenovo-thinkpad-x220
            #   { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; }
          ];
        };
        terminal-nx-01 = mkX86_64 "terminal-nx-01" {
          host = topoIp "terminal-nx-01";
          extraModules = [
            ./users/build.nix
            {
              nixpkgs.config.nvidia.acceptLicense = true;
              environment.systemPackages = [
                parsecgaming.packages.x86_64-linux.parsecgaming
              ];
            }
          ];
        };

        cortex-alpha = mkX86_64 "cortex-alpha" {
          host = topoIp "cortex-alpha";
          extraModules = [
            ./environments/neovim.nix
            ./services/dynamic_domain_gandi.nix
          ];
        };
        local-nas = mkX86_64 "local-nas" {
          host = topoIp "local-nas";
        };
        alpha-one = mkX86_64 "alpha-one" {
          host = topoIp "alpha-one";
          extraModules = [ ./users/build.nix { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
        };
        alpha-three = mkX86_64 "alpha-three" {
          host = topoIp "alpha-three";
          extraModules = [
            ./users/build.nix
            hype-train-claw.nixosModules.zeroclaw
            ./services/zeroclaw.nix
            {
              nixpkgs.config.nvidia.acceptLicense = true;
            }
          ];
        };

        LINDA = mkX86_64 "LINDA" {
          host = topoIp "LINDA";
          buildOn = "remote";
          extraModules = [
            ./users/build.nix
            xlibre-overlay.nixosModules.overlay-xlibre-xserver
            xlibre-overlay.nixosModules.overlay-all-xlibre-drivers
            xlibre-overlay.nixosModules.nvidia-ignore-ABI
            denton-glasses.nixosModules.eye-tracking
            denton-glasses.nixosModules.voxtype
            # self.inputs.LLM-CORE.nixosModules.opencode-fleet  # Disabled for overlord-I — re-enable as part of overlord-II
            {
              programs.ratty = {
                enable = true;
                gpuBackend = "vulkan";
                gpuAdapter = "RTX 3060";
              };
              environment.systemPackages = [
                parsecgaming.packages.x86_64-linux.parsecgaming
                star-citizen.packages.x86_64-linux.rsi-launcher
              ];
            }
          ];
        };
        gaming-host-1 = mkX86_64 "gaming-host-1" {
          host = topoIp "gaming-host-1";
          #sshUser = "John88";
          #sshPort = 22;
          extraModules = [ ];
        };
        remote-worker = mkX86_64 "remote-worker" {
          host = topoIp "remote-worker";
          extraModules = [
            ./users/build.nix
            # self.inputs.LLM-CORE.nixosModules.opencode-fleet  # Disabled for overlord-I — re-enable as part of overlord-II
            {
              services.nginx = {
                enable = true;
                virtualHosts = {
                  "csfinancialconsulting.com" = {
                    forceSSL = true;
                    enableACME = true;
                    listenAddresses = [ "193.16.42.101" "10.0.1.42" "10.88.127.50" ]; #todo: handle this assignment in a fixed fashion 82.5.173.252
                    locations."/" = {
                      root = carmelsite.packages.x86_64-linux.default;
                      #proxywebsockets = false; # needed if you need to use websocket
                    };
                  };
                  "csfincon.us" = {
                    forceSSL = true;
                    enableACME = true;
                    listenAddresses = [ "193.16.42.101" "10.0.1.42" "10.88.127.50" ]; #todo: handle this assignment in a fixed fashion 82.5.173.252
                    locations."/" = {
                      root = carmelsite.packages.x86_64-linux.default;
                      #proxywebsockets = false; # needed if you need to use websocket
                    };
                  };
                  "carmel-staging.johnbargman.net" = {
                    useACMEHost = "johnbargman.net";
                    forceSSL = true;
                    listenAddresses = [ "193.16.42.101" "10.0.1.42" "10.88.127.50" ]; #todo: handle this assignment in a fixed fashion 82.5.173.252
                    locations."/" = {
                      root = carmelsite.packages.x86_64-linux.default;
                      #proxywebsockets = false; # needed if you need to use websocket
                    };
                  };
                };
              };
            }
          ];

        };
        remote-builder = mkX86_64 "remote-builder" {
          extraModules = [ ./users/build.nix ];
          host = topoIp "remote-builder";
        };

        bargman-greeter-vm = nixpkgs_stable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./environments/i3wm_darthpjb.nix
            ./environments/bargman-greeter-vm.nix
            {
              _module.args = {
                inherit self;
                inherit bargman-assets;
              };
              networking.hostName = "bargman-greeter-vm";
              nixpkgs.hostPlatform = "x86_64-linux";
              system.stateVersion = "25.11";
            }
          ];
        };
      };

      # Dormant machines: configuration preserved for golden tests but excluded
      # from nixosConfigurations to prevent accidental deployment.
      # Move back to nixosConfigurations when reactivating in person.
      dormantConfigurations = {
        alpha-two = mkX86_64 "alpha-two" {
          host = topoIp "alpha-two";
          extraModules = [ ./users/build.nix { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
        };
        storage-array = mkX86_64 "storage-array" {
          host = topoIp "storage-array";
        };
        display-0 = mkAarch64 "display-0" {
          host = topoIp "display-0";
          hardware = nixos-hardware.nixosModules.raspberry-pi-3;
          extraModules = [ ./modifier_imports/minimal.nix ./modifier_imports/pi-firmware.nix ];
        };
      };

      checks."x86_64-linux" = {
        nixpkgs-fmt = lint-utils.linters.x86_64-linux.nixpkgs-fmt { src = self; };

        # Network topology golden check for cortex-alpha (manual run)
        network-config-cortex-alpha = nixpkgs.writeShellApplication {
          name = "network-config-cortex-alpha";
          meta.description = "Check network config against golden file";
          runtimeInputs = [ nixpkgs.jq ];
          text = ''
            echo "Generating current network config for cortex-alpha..."
            nix run .#dump-config -- cortex-alpha | jq -S . > /tmp/current-network.json

            echo "Comparing with golden..."
            if diff -u ${self}/goldens/cortex-alpha.json /tmp/current-network.json; then
              echo "✓ Network config matches golden for cortex-alpha"
            else
              echo "✗ Network configuration has changed from golden!"
              echo "If intentional, update with:"
              echo "  nix run .#dump-config -- cortex-alpha > goldens/cortex-alpha.json"
              exit 1
            fi
          '';
        };

        topology-coverage =
          let
            coverage = import ./lib/golden_coverage.nix { inherit self; };
          in
          if !coverage.isComplete then
            throw "Topology coverage incomplete. Missing: ${builtins.toJSON coverage.missing}"
          else
            nixpkgs.runCommand "topology-coverage-check" { } ''
              echo "Topology coverage: ${toString coverage.coveragePercent}%"
              echo "Machines: ${toString coverage.coveredCount}/${toString coverage.totalMachines}"
              touch $out
            '';

        bargman-greeter-login-test = nixpkgs.callPackage ./tests/bargman-greeter-login/default.nix {
          nixosModule = {
            imports = [ ./environments/i3wm_darthpjb.nix ./environments/bargman-greeter-vm.nix ];
            _module.args = {
              inherit self;
              inherit bargman-assets;
            };
          };
          resourceDir = ./tests/bargman-greeter-login/resources;
        };

        # Minecraft server lifecycle test:
        # Boots VM, waits for "Done", verifies RCON, sends stop, checks clean exit
        minecraft-server-test = nixpkgs.callPackage ./tests/minecraft-server/default.nix {
          minecraft-curseforge-all-the-mons = self.packages.x86_64-linux.minecraft-curseforge-all-the-mons;
          minecraft-curseforge-module = ./server_services/game_servers/minecraft-curseforge.nix;
        };
      };

      # CI data exposed under legacyPackages (not a standard flake output type)
      legacyPackages."x86_64-linux" = {
        ci-info = ci-generator.ci-info;
        ci = ci;
      };
    };
}
