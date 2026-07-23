{
  description = "A NixOS flake for John Bargman's machine provisioning";

  nixConfig = {
    extra-substituters = [ "https://install.determinate.systems" ];
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "install.determinate.systems:a7GMGXFqz7lFjOE45sTRq1g/RX6KFHRKHXOHTi1uFhM="
    ];
  };

  inputs = {
    carmelsite.url = "git+https://gitlab.com/mecha-team-zero/carmelsite.git";
    deadnix.url = "https://flakehub.com/f/astro/deadnix/1";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nix.url = "github:darthpjb/nix-src/fix/ssh-master-localcommand-protocol-leak";
    };
    disko = { url = "https://flakehub.com/f/nix-community/disko/1"; inputs.nixpkgs.follows = "nixpkgs_unstable"; };
    secrix.url = "github:Platonic-Systems/secrix";
    nixinate = { url = "github:Bargman-Tech/nixinate"; inputs.nixpkgs.follows = "nixpkgs_unstable"; };
    nixpkgs_stable.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs_unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0";
    nixpkgs_llm.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
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
    LLM-CORE = { url = "gitlab:mecha-team-zero/llm-core"; inputs.nixpkgs.follows = "nixpkgs_llm"; inputs.nix-mcp-servers.inputs.nixpkgs.follows = "nixpkgs_stable"; };
  };
  outputs = { self, deadnix, determinate, disko, nixinate, nixos-hardware, nixpkgs_stable, nixpkgs_unstable, nixpkgs_llm, hype-train-outlaw, star-citizen, parsecgaming, secrix, hype-train-claw, carmelsite, xlibre-overlay, ratty, ikbaeb-th, bargman-assets, denton-glasses, personal-site, LLM-CORE }:
    let
      nixpkgs = nixpkgs_stable.legacyPackages.x86_64-linux;
      lib = nixpkgs_stable.lib;
      topoRegistry = import ./lib/topology/mkRegistry.nix { inherit lib; };
      # Helper: derive IP from coordinate (subnet + peer_id)
      coordToIp = coord:
        let
          parts = lib.splitString "/" coord.subnet;
          ip = builtins.head parts;
          octets = lib.splitString "." ip;
          prefix = lib.concatStringsSep "." (lib.init octets);
        in
        "${prefix}.${toString coord.peer_id}";
      # Backward-compatible topo attrset derived from JSON registry
      topo = lib.mapAttrs
        (name: host:
          let
            coords = host.coordinate or [ ];
            wgCoords = builtins.filter (c: c.plane_name == "wg") coords;
            wgCoord = if wgCoords != [ ] then builtins.head wgCoords else null;
            # Filter to only include standard network interfaces (skip MAC-based aliases)
            otherCoords = builtins.filter
              (c:
                c.plane_name != "wg" && c.plane_name != "tailscale-platonic"
                && !lib.hasPrefix "mac:" c.interface
              )
              coords;
            lan = lib.listToAttrs (map
              (c: {
                name = coordToIp c;
                value = c.interface;
              })
              otherCoords);
          in
          (if wgCoord != null then { wireguard = coordToIp wgCoord; } else { })
          // (if lan != { } then { inherit lan; } else { })
        )
        topoRegistry.hosts;
      # Get wireguard IP for a machine from topology registry
      topoIp = machineName:
        let
          host = topoRegistry.hosts.${machineName} or null;
          wgCoords =
            if host != null then
              builtins.filter (c: c.plane_name == "wg") (host.coordinate or [ ])
            else [ ];
          wgCoord = if wgCoords != [ ] then builtins.head wgCoords else null;
        in
        if wgCoord != null then
          coordToIp wgCoord
        else throw "topoIp: ${machineName} has no WG coordinate in topology JSON";
      globalArgs = {
        inherit self;
        inherit ikbaeb-th;
        inherit bargman-assets;
        inherit denton-glasses;
        inherit personal-site;
        inherit LLM-CORE;
        pkgs_llm = nixpkgs_llm.legacyPackages.x86_64-linux;
      };
      minecraft-curseforge-builder = nixpkgs.callPackage ./pkgs/minecraft-curseforge { };
      prometheus-mcp-server-builder = nixpkgs.callPackage ./pkgs/prometheus-mcp-server { };
      commonModules = [
        secrix.nixosModules.default
        ratty.nixosModules.default
        ./modules/topology-derive.nix
        ./configuration.nix
        ./modules/ssh-multiplex.nix
        # Skip nix test suite — OOMs on remote builders during source build.
        # The forked nix (darthpjb/nix-src) builds from source, not from cache.
        ({ pkgs, lib, ... }: {
          nix.package = lib.mkForce (determinate.inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: { doCheck = false; }));
        })
        {
          programs.ssh.knownHosts = mkKnownHosts self.nixosConfigurations;
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
        }
      ];
      mkX86_64 = hostname: { extraModules ? [ ], hostPubKey ? builtins.readFile ./secrets/public_keys/host_keys/${hostname}.pub, host ? null, sshUser ? "deploy", buildOn ? "local", dt ? true, sshPort ? 1108, images ? { } }:
        nixpkgs_stable.lib.nixosSystem {
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
                unstable = import nixpkgs_unstable { localSystem = "x86_64-linux"; config.allowUnfree = true; };
                nixinate = {
                  inherit host sshUser buildOn;
                  port = sshPort;
                  inherit images;
                };
              };
            }
          ];
        };
      mkAarch64 = hostname: { extraModules ? [ ], hostPubKey ? builtins.readFile ./secrets/public_keys/host_keys/${hostname}.pub, host ? null, sshUser ? "deploy", buildOn ? "local", dt ? true, hardware ? nixos-hardware.nixosModules.raspberry-pi-4 }:
        nixpkgs_unstable.lib.nixosSystem {
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
                unstable = import nixpkgs_unstable { localSystem = "aarch64-linux"; config.allowUnfree = true; };
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

      # Parallelism control for CI build jobs — two axes:
      #   Nix-level: max-jobs, cores, builders per derivation
      #   GitHub Actions-level: max-parallel concurrent matrix jobs
      # x86: all-at-once (shared derivations benefit from full concurrency)
      # ARM: constrained (RPi memory limits)
      ciParallelism = {
        default = {
          max-jobs = "auto";
          cores = "0";
          max-parallel = 10; # GitHub Actions: concurrent matrix jobs
        };
        perSystem = {
          aarch64-linux = {
            max-jobs = "2";
            cores = "2";
            max-parallel = 2; # ARM: only 2 concurrent builds
          };
        };
      };

      # CI/CD Configuration
      ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; parallelism = ciParallelism; };

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

        # Check CI config against golden
        check-ci = {
          type = "app";
          meta.description = "Check CI config against golden file";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "check-ci";
            runtimeInputs = [ nixpkgs.jq nixpkgs.diffutils nixpkgs.coreutils ];
            text = ''
              ${lib.getExe' nixpkgs.coreutils "echo"} "Checking CI configuration against golden..."
              nix eval --json .#ci.ci.github-actions 2>/dev/null | ${lib.getExe nixpkgs.jq} -S . > /tmp/current-ci.json
              if ${lib.getExe' nixpkgs.diffutils "diff"} -u "${self}/goldens/ci.json" /tmp/current-ci.json; then
                ${lib.getExe' nixpkgs.coreutils "echo"} "CI config matches golden"
              else
                ${lib.getExe' nixpkgs.coreutils "echo"} "CI configuration has changed from golden!"
                ${lib.getExe' nixpkgs.coreutils "echo"} "If intentional, update with:"
                ${lib.getExe' nixpkgs.coreutils "echo"} "  nix eval --json .#ci.ci.github-actions | jq -S . > goldens/ci.json"
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
                    config = (flake.nixosConfigurations."'"$MACHINE"'" or flake.dormantConfigurations."'"$MACHINE"'").config;
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
          squaremap-neoforge = nixpkgs.callPackage ./pkgs/minecraft-curseforge/squaremap.nix {
            moonrise-neoforge = self.packages.x86_64-linux.moonrise-neoforge;
          };
          moonrise-neoforge = nixpkgs.callPackage ./pkgs/minecraft-curseforge/moonrise.nix { };
          bargman-greeter-vm = self.nixosConfigurations.bargman-greeter-vm.config.system.build.vm;
          bargman-greeter-vm-bootloader = self.nixosConfigurations.bargman-greeter-vm.config.system.build.vmWithBootLoader;
        } // (nixinate.lib.genImages.x86_64-linux self);
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
          modules = [
            "${nixpkgs_unstable}/nixos/modules/installer/sd-card/sd-image-armv7l-multiplatform.nix"
            "${nixpkgs_unstable}/nixos/modules/profiles/minimal.nix"
            ./machines/beta/1.nix
            {
              nixpkgs.hostPlatform = "armv7l-linux";
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
          dt = true; # Determinate Nix required — this machine IS the aarch64 remote builder
          extraModules = [
            ./users/deployment.nix
            ./users/build.nix
          ];
        };
        # Generic ARM bootstrap image — reusable for ALL ARM devices
        # No WG, no device-specific config, open SSH on port 22
        arm-bootstrap = nixpkgs_unstable.lib.nixosSystem {
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
                unstable = import nixpkgs_unstable { localSystem = "aarch64-linux"; config.allowUnfree = true; };
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
          extraModules = [ ./users/build.nix LLM-CORE.nixosModules.opencode-fleet { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
        };
        alpha-three = mkX86_64 "alpha-three" {
          host = topoIp "alpha-three";
          images = {
            raw = {
              enable = true;
              imageSize = "20G";
              espSize = "1024M";
              swapSize = "8G";
            };
            installer.enable = true;
          };
          extraModules = [
            ./users/build.nix
            hype-train-claw.nixosModules.zeroclaw
            ./services/zeroclaw.nix
            LLM-CORE.nixosModules.opencode-fleet
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
            LLM-CORE.nixosModules.opencode-fleet
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
            # Topology-derive owns johnbargman.net/.com vhosts (see topology/remote-worker.json).
            # Carmelsite client sites remain machine overlay (merge with topology nginx.enable).
            {
              services.nginx = {
                statusPage = true;
                virtualHosts = {
                  "csfinancialconsulting.com" = {
                    forceSSL = true;
                    enableACME = true;
                    listenAddresses = [ "193.16.42.101" "10.0.1.42" "10.88.127.50" ];
                    locations."/" = {
                      root = carmelsite.packages.x86_64-linux.default;
                    };
                  };
                  "csfincon.us" = {
                    forceSSL = true;
                    enableACME = true;
                    listenAddresses = [ "193.16.42.101" "10.0.1.42" "10.88.127.50" ];
                    locations."/" = {
                      root = carmelsite.packages.x86_64-linux.default;
                    };
                  };
                  "carmel-staging.johnbargman.net" = {
                    useACMEHost = "johnbargman.net";
                    forceSSL = true;
                    listenAddresses = [ "193.16.42.101" "10.0.1.42" "10.88.127.50" ];
                    locations."/" = {
                      root = carmelsite.packages.x86_64-linux.default;
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
        formatting = nixpkgs.runCommand "check-formatting"
          { buildInputs = [ nixpkgs.nixpkgs-fmt ]; }
          "nixpkgs-fmt --check ${self} && touch $out";

        deadnix = nixpkgs.writeShellApplication {
          name = "run-deadnix";
          meta.description = "Detect dead Nix code";
          runtimeInputs = [ deadnix.packages.x86_64-linux.default ];
          text = ''exec deadnix --no-lambda-pattern-names "${self}"'';
        };

        # Network topology golden check for all machines
        # Pure Nix evaluation — compares serialized config against golden files at build time
        network-config =
          let
            machines = builtins.attrNames self.nixosConfigurations;
            serializer = import ./lib/serialize-config.nix { inherit lib; };
            # Pre-compute JSON for each machine at eval time
            # unsafeDiscardStringContext strips derivation references so builtins.toFile accepts the string
            machineJsonFiles = lib.genAttrs machines (machine:
              let
                config = self.nixosConfigurations.${machine}.config;
                json = builtins.unsafeDiscardStringContext (
                  builtins.toJSON (serializer.serializeConfig config)
                );
              in
              builtins.toFile "network-config-${machine}.json" json
            );
          in
          nixpkgs.runCommand "network-config-golden-check"
            {
              buildInputs = [ nixpkgs.jq nixpkgs.diffutils ];
              goldenSrc = "${self}/goldens";
            }
            ''
              PASS=true
              ${lib.concatMapStringsSep "\n" (machine: ''
                if [ -f "$goldenSrc/${machine}.json" ]; then
                  echo "Checking ${machine}..."
                  ${lib.getExe nixpkgs.jq} -S . < "${machineJsonFiles.${machine}}" > /tmp/current.json
                  if ${lib.getExe' nixpkgs.diffutils "diff"} -u "$goldenSrc/${machine}.json" /tmp/current.json; then
                    echo "  ✓ ${machine} matches golden"
                  else
                    echo "  ✗ ${machine} differs from golden!"
                    PASS=false
                  fi
                else
                  echo "Skipping ${machine} (no golden file)"
                fi
              '') machines}
              if [ "$PASS" != "true" ]; then
                echo ""
                echo "Golden check failed. If changes are intentional, update with:"
                echo "  nix run .#dump-config -- <machine> > goldens/<machine>.json"
                exit 1
              fi
              echo ""
              echo "All golden checks passed"
              touch $out
            '';

        topology-coverage =
          let
            coverage = import ./lib/golden_coverage.nix { inherit self lib; };
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
