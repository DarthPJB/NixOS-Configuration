{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    carmelsite = { url = "git+ssh://git@gitlab.platonic.systems/john.bargman/carmelsite"; };
    deadnix = { url = "github:astro/deadnix"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    hyprland.url = "github:hyprwm/Hyprland";
    lint-utils = { url = "github:homotopic/lint-utils"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    nixinate = { url = "github:DarthPJB/nixinate"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    secrix.url = "github:Platonic-Systems/secrix";
    #   secure_pkgs.url = "https://flakehub.com/f/DeterminateSystems/secure/0";
    nixpkgs_stable.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs_unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nix-mcp-servers.url = "github:cameronfyfe/nix-mcp-servers";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    hype-train-claw.url = "github:marijanp/zeroclaw";
    hype-train-outlaw.url = "git+ssh://git@gitlab.com/mecha-team-zero/macha-orchestration";
    star-citizen.url = "github:LovingMelody/nix-citizen";
  };
  outputs = { self, deadnix, determinate, hyprland, lint-utils, nixinate, nix-mcp-servers, nixos-hardware, nixpkgs_stable, nixpkgs_unstable, hype-train-outlaw, star-citizen, parsecgaming, secrix, hype-train-claw, carmelsite }:
    let
      nixpkgs = nixpkgs_stable.legacyPackages.x86_64-linux;
      lib = nixpkgs_stable.lib;
      globalArgs = {
        inherit self;
      };
      commonModules = [
        secrix.nixosModules.default
        ./configuration.nix
        {
          programs.ssh.knownHosts = mkKnownHosts self.nixosConfigurations;
          nixpkgs.config.allowUnfree = true;
          system.stateVersion = "25.11";
          secrix.defaultEncryptKeys.John88 = [
            (builtins.readFile ./secrets/public_keys/JOHN_BARGMAN_ED_25519.pub) # Four years ago matthew croughan said "why bother putting that there?" so... This is why.
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
        lib.filterAttrs (name: value: value != null)
          (lib.mapAttrs
            (name: cfg:
              let
                hostPubKey = cfg.config.secrix.hostPubKey or null;
              in
              if hostPubKey != null then {
                hostNames = [ name "${name}.johnbargman.net" ];
                publicKey = hostPubKey;
              } else null
            )
            nixosConfigs);

      # CI/CD Configuration
      ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; };

      # CI Generator Scripts
      ci-generator = import ./ci/generate-workflow.nix { inherit self lib; pkgs = nixpkgs; };
    in
    {
      formatter."x86_64-linux" = nixpkgs.nixpkgs-fmt;
      apps."x86_64-linux" = { secrix = secrix.secrix self; } // (nixinate.lib.genDeploy.x86_64-linux self) // {
        # Network Reality Golden Generation
        generate-golden = {
          type = "app";
          meta.description = "Generate golden network reality JSON for a machine (outputs to stdout)";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "generate-golden";
            runtimeInputs = [ nixpkgs.jq ];
            text = ''
              if [ -z "$1" ]; then
                echo "Usage: nix run .#generate-golden <machine-name>"
                echo "Example: nix run .#generate-golden cortex-alpha > real-topology/golden/cortex-alpha.json"
                exit 1
              fi
              MACHINE="$1"
              nix eval --json --impure \
                --expr '
                  let
                    flake = builtins.getFlake (builtins.toString ./.);
                    lib = (import <nixpkgs> {}).lib;
                    topology = import ./real-topology/default.nix { inherit lib; self = flake; };
                  in
                  topology.generateGolden "'"$MACHINE"'"
                ' | jq -S .
            '';
          });
        };

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
              nix run .#generate-golden -- "$MACHINE" | jq -S . > /tmp/current-network.json
                
              if diff -u "${self}/real-topology/golden/$MACHINE.json" /tmp/current-network.json; then
                echo "✓ Network config matches golden for $MACHINE"
              else
                echo "✗ Network configuration has changed from golden!"
                echo "If intentional, update with:"
                echo "  nix run .#generate-golden -- $MACHINE > real-topology/golden/$MACHINE.json"
                exit 1
              fi
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
      };

      packages = {
        #        "x86_64-linux".local-worker-image = mkLibVirtImage {
        #          config = self.nixosConfigurations.local-worker.config;
        #          name = "local-worker-image";
        #        };
        "aarch64-linux" = mkUncompressedSdImages [
          self.nixosConfigurations.print-controller
          self.nixosConfigurations.display-0
          self.nixosConfigurations.display-1
          self.nixosConfigurations.display-2
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
          host = "10.88.127.41";
          extraModules = [ ./users/build.nix ];
        };
        display-2 = mkAarch64 "display-2" {
          host = "10.88.127.42";
          extraModules = [ ./users/build.nix ];
        };
        print-controller = mkAarch64 "print-controller" {
          host = "10.88.127.30";
          hardware = nixos-hardware.nixosModules.raspberry-pi-3;
          extraModules = [ ./server_services/klipper.nix ];
        };
        display-0 = mkAarch64 "display-0" {
          host = "display-0.johnbargman.net";
          hardware = nixos-hardware.nixosModules.raspberry-pi-3;
          extraModules = [ ./modifier_imports/minimal.nix ./modifier_imports/pi-firmware.nix ];
        };

        terminal-zero = mkX86_64 "terminal-zero" {
          host = "10.88.127.20";
          extraModules = [
            ./modifier_imports/central-builder.nix
            nixos-hardware.nixosModules.lenovo-thinkpad-x220
            { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; }
          ];
        };
        terminal-nx-01 = mkX86_64 "terminal-nx-01" {
          host = "10.88.127.21";
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

        #  local-worker = mkX86_64 "local-worker" {
        #    host = "10.88.127.89";
        #    extraModules = [ "${nixpkgs_stable}/nixos/modules/virtualisation/libvirtd.nix" ];
        #  };

        cortex-alpha = mkX86_64 "cortex-alpha" {
          host = "10.88.127.1";
          extraModules = [
            ./environments/neovim.nix
            ./services/dynamic_domain_gandi.nix
          ];
        };
        local-nas = mkX86_64 "local-nas" {
          host = "10.88.127.3";
        };
        alpha-one = mkX86_64 "alpha-one" {
          host = "10.88.127.108";
          extraModules = [ ./users/build.nix { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
        };
        alpha-two = mkX86_64 "alpha-two" {
          host = "10.88.127.21";
          extraModules = [ ./users/build.nix { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
        };
        alpha-three = mkX86_64 "alpha-three" {
          host = "10.88.127.107";
          extraModules = [ ./users/build.nix ];
        };

        LINDA = mkX86_64 "LINDA" {
          host = "10.88.127.88";
          buildOn = "remote";
          extraModules = [
            ./users/build.nix
            {
              environment.systemPackages = [
                parsecgaming.packages.x86_64-linux.parsecgaming
                star-citizen.packages.x86_64-linux.rsi-launcher
              ];
            }
          ];
        };
        gaming-host-1 = mkX86_64 "gaming-host-1" {
          host = "10.88.127.52";
          #sshUser = "John88";
          #sshPort = 22;
          extraModules = [ ];
        };
        remote-worker = mkX86_64 "remote-worker" {
          host = "10.88.127.50";
          extraModules = [
            ./users/build.nix
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
        storage-array = mkX86_64 "storage-array" {
          host = "10.88.127.4";
        };
        remote-builder = mkX86_64 "remote-builder" {
          extraModules = [ ./users/build.nix ];
          host = "10.88.127.51";
        };
      };

      checks."x86_64-linux" = {
        deadnix = nixpkgs.writeShellApplication {
          name = "run-deadnix";
          meta.description = "runs deadnix on the flake source";
          text = ''
            nix run ${deadnix}#deadnix "${self}"
          '';
        };

        nixpkgs-fmt = lint-utils.linters.x86_64-linux.nixpkgs-fmt { src = self; };

        # Network topology golden check for cortex-alpha (manual run)
        network-config-cortex-alpha = nixpkgs.writeShellApplication {
          name = "network-config-cortex-alpha";
          meta.description = "Check network config against golden file";
          runtimeInputs = [ nixpkgs.jq ];
          text = ''
            echo "Generating current network config for cortex-alpha..."
            nix run .#generate-golden -- cortex-alpha | jq -S . > /tmp/current-network.json
            
            echo "Comparing with golden..."
            if diff -u ${self}/real-topology/golden/cortex-alpha.json /tmp/current-network.json; then
              echo "✓ Network config matches golden for cortex-alpha"
            else
              echo "✗ Network configuration has changed from golden!"
              echo "If intentional, update with:"
              echo "  nix run .#generate-golden -- cortex-alpha > real-topology/golden/cortex-alpha.json"
              exit 1
            fi
          '';
        };
      };

      # CI Information Output
      ci-info = ci-generator.ci-info;

      # CI Configuration (for external access)
      ci = ci;
    };
}
