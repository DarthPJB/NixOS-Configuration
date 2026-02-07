{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    deadnix = { url = "github:astro/deadnix"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    hyprland.url = "github:hyprwm/Hyprland";
    lint-utils = { url = "github:homotopic/lint-utils"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    nixinate = { url = "github:DarthPJB/nixinate"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    secrix.url = "github:Platonic-Systems/secrix";
    nixpkgs_stable.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs_unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nix-mcp-servers.url = "github:cameronfyfe/nix-mcp-servers";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
  outputs = { self, deadnix, determinate, hyprland, lint-utils, nixinate, nix-mcp-servers, nixos-hardware, nixpkgs_stable, nixpkgs_unstable, parsecgaming, secrix }:
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
          nix.registry.nixpkgs.flake = nixpkgs_stable;
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
      mkAarch64 = hostname: { extraModules ? [ ], hostPubKey ? builtins.readFile ./secrets/public_keys/host_keys/${hostname}.pub, host ? null, sshUser ? "deploy", buildOn ? "local", dt ? true, hardware ? nixos-hardware.nixosModules.raspberry-pi-4 }:
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
    in
    {
      formatter."x86_64-linux" = nixpkgs.nixpkgs-fmt;
      apps."x86_64-linux" = { secrix = secrix.secrix self; } // (nixinate.lib.genDeploy.x86_64-linux self) // {
        deploy-all = {
          type = "app";
          meta.description = "itsa make the pizza delivery";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "deploy-all";
            runtimeInputs = with nixpkgs; [ nix jq figlet ];
            text = ''
              set -euo pipefail

              CONFIGS=$(nix flake show --json . \
                | jq -r '.apps."x86_64-linux" | keys[]' \
                | grep -E '^(terminal-zero|terminal-nx-01|cortex-alpha|data-storage|LINDA|remote-worker|storage-array|remote-builder|local-worker)$' || true)

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
          meta.description = "itsa make the pizza delivery";
          program = lib.getExe (nixpkgs.writeShellApplication {
            name = "build-all";
            runtimeInputs = with nixpkgs; [ nix jq figlet ];
            text = ''
              set -euo pipefail

              CONFIGS=$(nix flake show --json . \
                | jq -r '.apps."x86_64-linux" | keys[]' \
                | grep -E '^(terminal-zero|terminal-nx-01|cortex-alpha|data-storage|LINDA|remote-worker|storage-array|remote-builder|local-worker)$' || true)

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
      };

      packages = {
        "x86_64-linux".local-worker-image = mkLibVirtImage {
          config = self.nixosConfigurations.local-worker.config;
          name = "local-worker-image";
        };
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

        local-worker = mkX86_64 "local-worker" {
          host = "10.88.127.89";
          extraModules = [ "${nixpkgs_stable}/nixos/modules/virtualisation/libvirtd.nix" ];
        };

        cortex-alpha = mkX86_64 "cortex-alpha" {
          host = "10.88.127.1";
          extraModules = [ ./environments/neovim.nix ./services/dynamic_domain_gandi.nix ];
        };
        data-storage = mkX86_64 "local-nas" {
          host = "10.88.127.3";
          extraModules = [ ./users/build.nix ];
        };
        alpha-one = mkX86_64 "alpha-one" {
          host = "10.88.127.108";
          sshUser = "deploy";
          extraModules = [ ./users/build.nix { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
        };
        alpha-two = mkX86_64 "alpha-two" {
          host = "10.88.127.21";
          sshUser = "John88";
          extraModules = [{ nixpkgs.config.nvidia.acceptLicense = true; environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; }];
        };
        alpha-three = mkX86_64 "alpha-three" {
          host = "10.88.127.107";
          #     sshUser = "root";
          #    sshPort = 22;
          extraModules = [ ./users/build.nix { } ];
        };

        LINDA = mkX86_64 "LINDA" {
          host = "10.88.127.88";
          buildOn = "remote";
          extraModules = [ ./users/build.nix { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
        };

        remote-worker = mkX86_64 "remote-worker" {
          dt = false;
          host = "10.88.127.50";
        };
        storage-array = mkX86_64 "storage-array" {
          host = "10.88.127.4";
        };
        remote-builder = mkX86_64 "remote-builder" {
          dt = false;
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
      };
    };
}
