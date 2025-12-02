{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    deadnix = { url = "github:astro/deadnix"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    hyprland.url = "github:hyprwm/Hyprland";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    nixinate = { url = "github:DarthPJB/nixinate"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
#    nixinate = { url = "path:/speed-storage/repo/DarthPJB/nixinate"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    secrix.url = "github:DarthPJB/secrix";
    nixpkgs_stable.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs_legacy.url = "github:nixos/nixpkgs?ref=nixos-23.05";
    nixpkgs_unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
  # --------------------------------------------------------------------------------------------------
  outputs = { self, parsecgaming, nixos-hardware, hyprland, secrix, nixinate, nixpkgs_legacy, nixpkgs_unstable, nixpkgs_stable, determinate, deadnix }:
    let
      # ------------------------------------------------------------------
      # those handy little things.
      # ------------------------------------------------------------------  
      flake_pkgs = nixpkgs_stable.legacyPackages.x86_64-linux;
      lib = nixpkgs_stable.lib;
      # ------------------------------------------------------------------
      # Global args & common modules
      # ------------------------------------------------------------------
      globalArgs = {
        inherit self;
      };

      commonModules = [
        secrix.nixosModules.default
        ./configuration.nix
        {
          nixpkgs.config.allowUnfree = true;
          system.stateVersion = "25.11";
          secrix.defaultEncryptKeys.John88 = [
            (builtins.readFile ./public_key/id_ed25519_master.pub)
          ];
        }
      ];

      # ------------------------------------------------------------------
      # Architecture-specific builders
      # ------------------------------------------------------------------
      mkX86_64 = name: hostname: { extraModules ? [ ], hostPubKey ? null, host ? null, sshUser ? "deploy", buildOn ? "local", dt ? false }:
        nixpkgs_stable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = commonModules ++ extraModules ++ (if dt then [ determinate.nixosModules.default ] else [ ]) ++ [
            ./machines/${name}
            {
              networking.hostName = hostname;
              secrix.hostPubKey = if hostPubKey != null then hostPubKey else null;

              _module.args = globalArgs // {
                unstable = import nixpkgs_unstable { system = "x86_64-linux"; config.allowUnfree = true; };
                nixinate = {
                  inherit host sshUser buildOn;
                  port = 1108;
                };
              };
            }
          ];
        };

      mkAarch64 = name: hostname: { extraModules ? [ ], hostPubKey ? null, host ? null, sshUser ? "deploy", buildOn ? "local", dt ? false, hardware ? nixos-hardware.nixosModules.raspberry-pi-4 }:
        nixpkgs_stable.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${nixpkgs_stable}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            "${nixpkgs_stable}/nixos/modules/profiles/minimal.nix"
            hardware
          ] ++ commonModules ++ extraModules ++ (if dt then [ determinate.nixosModules.default ] else [ ]) ++ [
            ./machines/${name}
            {
              nixpkgs.buildPlatform = "x86_64-linux"; # build arch (optional, defaults to local)
              nixpkgs.hostPlatform = "aarch64-linux"; # target run arch
              networking.hostName = hostname; # handles display/1.nix → "1"
              secrix.hostPubKey = if hostPubKey != null then hostPubKey else null;
              documentation = { dev.enable = false; man.enable = false; info.enable = false; enable = false; };
              disabledModules = [
                "profiles/all-hardware.nix"
                "profiles/base.nix"
              ];

              _module.args = globalArgs // {
                unstable = import nixpkgs_unstable { system = "aarch64-linux"; config.allowUnfree = true; };
                nixinate = {
                  inherit host sshUser buildOn;
                  port = 1108;
                };
              };
            }
          ];
        };
      # ------------------------------------------------------------------
      # Image-specific builders
      # ------------------------------------------------------------------
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
      formatter."x86_64-linux" = flake_pkgs.nixpkgs-fmt;
      apps."x86_64-linux" = { secrix = secrix.secrix self; } // (nixinate.lib.genDeploy.x86_64-linux self) //
        {
          deploy-all = {
            type = "app";
            meta.description = "itsa make the pizza delivery";
            program = lib.getExe (flake_pkgs.writeShellApplication {
              name = "deploy-all";
              runtimeInputs = with flake_pkgs; [ nix jq figlet ];
              text = ''
                # Fail fast
                set -euo pipefail

                # Get all nixinate-generated apps (they are under apps.x86_64-linux)
                CONFIGS=$(nix flake show --json . \
                  | jq -r '.apps."x86_64-linux" | keys[]' \
                  | grep -E '^(terminal-zero|terminal-nx-01|cortex-alpha|data-storage|LINDA|remote-worker|storage-array|remote-builder|local-worker)$' || true)

                if [ -z "$CONFIGS" ]; then
                  figlet "No deployable configurations found."
                  exit 1
                fi

                # Optional argument: pass to every nix run
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
        };

      # -----------------------------------IMAGES-------------------------------------------------
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
        #        "armv7l-linux" = mkUncompressedSdImages [
        #          self.nixosConfigurations.beta-one
        #        ];
        #        "riscv64-linux" = mkUncompressedSdImages [
        #          self.nixosConfigurations.beta-two
        #        ];
        #
      };
      # --------------------------------------------------------------------------------------------------
      nixosConfigurations = {

        # -----------------------------------ARM DEVICES-------------------------------------------------
        #                beta-one = nixpkgs_legacy.legacyPackages.x86_64-linux.pkgsCross.armv7l-hf-multiplatform.nixos 
        #		{
        #                  system = "armv7l-linux";
        #                  modules = [
        #          	    "${nixpkgs_legacy}/nixos/modules/installer/sd-card/sd-image-armv7l-multiplatform.nix"
        #                    secrix.nixosModules.default
        #                    nixos-hardware.nixosModules.raspberry-pi-2
        #                    ./machines/beta/1.nix
        #             #       ./configuration.nix
        #                    ./locale/home_networks.nix
        #                    {
        #        
        #	             # nixpkgs.localSystem.system = "aarch64-linux";
        #        	     # nixpkgs.crossSystem.system = "armv7l-linux";
        #                      secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
        #                      # secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPcOQZcWlN4XK5OYjI16PM/BWK/8AwKePb1ca/ZRuR1p root@display-2";
        #                      system.stateVersion = "24.11";
        #                      _module.args =
        #                        {
        #                          inherit self;
        #                          nixinate = {
        #                            port = "1108";
        #                            host = "10.88.128.126";
        #                            sshUser = "John88";
        #                 
        #                 
        #                            buildOn = "local";
        #                          };
        #                        };
        #                    }
        #                  ];
        #                };
        #        beta-two = nixpkgs_unstable.lib.nixosSystem {
        #          system = "riscv64-linux";
        #          modules = [
        #            determinate.nixosModules.default
        #            "${nixos-hardware}/starfive/visionfive/v1/sd-image-installer.nix"
        #            "${nixpkgs_unstable}/nixos/modules/profiles/minimal.nix"
        #            secrix.nixosModules.default
        #            ./machines/beta/2.nix
        #            ./configuration.nix
        #            ./locale/home_networks.nix
        #            {
        #              # the platform that performs the build-step
        #              disabledModules = [
        #                "profiles/all-hardware.nix"
        #                "profiles/base.nix"
        #              ];
        #              nixpkgs.localSystem.system = "x86_64-linux";
        #              nixpkgs.crossSystem = {
        #                config = "riscv64-unknown-linux-gnu";
        #                system = "riscv64-linux";
        #              };
        #              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
        #              # secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPcOQZcWlN4XK5OYjI16PM/BWK/8AwKePb1ca/ZRuR1p root@display-2";
        #              system.stateVersion = "24.11";
        #              _module.args =
        #                {
        #                  unstable = import nixpkgs_unstable { system = "x86_64-linux"; config.allowUnfree = true; };
        #                  inherit self;
        #                  nixinate = {
        #                    port = "1108";
        #                    host = "10.88.127.127";
        #                    sshUser = "John88";
        #         
        #         
        #                    buildOn = "local";
        #                  };
        #                };
        #            }
        #          ];
        #        };
        display-1 = mkAarch64 "display/1.nix" "display-1" { hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOxb+iAm5nTcC3oRsMIcxcciKRj8VnGpp1JIAdGVTZU root@display-1"; host = "10.88.127.41"; };
        display-2 = mkAarch64 "display/2.nix" "display-2" {
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPcOQZcWlN4XK5OYjI16PM/BWK/8AwKePb1ca/ZRuR1p root@display-2";
          host = "10.88.127.42";
          extraModules = [ hyprland.nixosModules.default ./users/build.nix ];
        };
        print-controller = mkAarch64 "print-controller" "print-controller" {
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqeo8ceyMoi+SIRP5hhilbhJvFflphD0efolDCxccj9";
          host = "10.88.127.30";
          sshUser = "John88";
          extraModules = [ ./server_services/klipper.nix ];
        };
        display-0 = mkAarch64 "display/0.nix" "display-0" {
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkAJhTTF+WVWixTwIvEtRq5KdpjxPy4ptlcmFSEetrU";
          host = "alpha-one.johnbargman.net";
          hardware = nixos-hardware.nixosModules.raspberry-pi-3;
          extraModules = [ ./modifier_imports/minimal.nix ./modifier_imports/pi-firmware.nix ];
        };

        # -----------------------------------TERMINALS-------------------------------------------------

        terminal-zero = mkX86_64 "terminal-zero" "terminal-zero" {
          dt = true;
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGlV1inLX9o+Qyf/B3dp6xjb4f9bGisvkT6eFL/f8JIl";
          host = "10.88.127.20";
          extraModules = [ nixos-hardware.nixosModules.lenovo-thinkpad-x220 { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
        };
        terminal-nx-01 = mkX86_64 "terminal-media" "terminal-nx-01" {
          dt = true;
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOK07xnXN3O2v4EZ7YUzWSL5O+Uf2vM6+jzxROWzaTD5";
          host = "10.88.127.21";
          extraModules = [{ nixpkgs.config.nvidia.acceptLicense = true; environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; }];
        };
        # -----------------------------------VIRTUALISED-------------------------------------------------

        local-worker = mkX86_64 "local-worker" "local-worker" {
          host = "10.88.127.89";
          extraModules = [ "${nixpkgs_stable}/nixos/modules/virtualisation/libvirtd.nix" ];
        };

        # -----------------------------------HOME LAB-------------------------------------------------
        cortex-alpha = mkX86_64 "cortex-alpha" "cortex-alpha" {
          dt = true;
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWAilZq7Ocl8zm96sSAy+fRo8wt5mMVuRQmEQsk4MsB root@cortex-alpha";
          host = "10.88.127.1";
          extraModules = [ ./environments/neovim.nix ./services/dynamic_domain_gandi.nix ];
        };
        data-storage = mkX86_64 "local-nas" "DataStorage" {
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINlCggPwFP5VX3YDA1iji0wxX8+mIzmrCJ1aHj9f1ofx";
          host = "10.88.127.3";
          extraModules = [ ./users/build.nix ];
        };
        alpha-two = mkX86_64 "alpha-two" "alpha-two" {
          dt = true;
          host = "10.88.127.21";
          sshUser = "John88";
          extraModules = [{ nixpkgs.config.nvidia.acceptLicense = true; environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; }];
        };
        LINDA = mkX86_64 "LINDA" "LINDACORE" {
          dt = true;
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDMfuVEzn9keN1iVk4rjJmB07+/ynTMaZCKPvbaZ1cF6";
          host = "10.88.127.88"; #"LINDACORE.johnbargman.net";
          buildOn = "remote";
          extraModules = [{ environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; }];
        };

        # -----------------------------------REMOTE SYSTEMS-------------------------------------------------
        remote-worker = mkX86_64 "remote-worker" "remote-worker" {
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPPSFI0IBhhtyMRcMtvHmMBbwklzXiOXw0OPVD3SEC+M";
          host = "10.88.127.50";
          extraModules = [ "${nixpkgs_stable}/nixos/modules/virtualisation/openstack-config.nix" ];
        };
        storage-array = mkX86_64 "storage-array" "storage-array" {
          dt = true;
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMfb/Bbr0PaFDyO92q+GXHHXTAlTYR4uSLm0jivou4IB";
          host = "10.88.127.4";
        };
        remote-builder = mkX86_64 "remote-builder" "remote-builder" {
          hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7Owkd/9PC7j/L5PbPXrSMx0Aw/1owIoCsfp7+5OKek";
          host = "10.88.127.51";
          extraModules = [ "${nixpkgs_stable}/nixos/modules/virtualisation/openstack-config.nix" ];
        };
        # -------------------------------------------------------------------------------------------------------
      };
      checks."x86_64-linux".deadnix = flake_pkgs.writeShellApplication {
        name = "run-deadnix";
        meta.description = "runs deadnix on the flake source";
        text = ''
          # Runs deadnix from nixpkgs or local flake
            nix run ${deadnix}#deadnix "${self}"
        '';
      };
      checks."x86_64-linux".formatting = flake_pkgs.writeShellApplication {
        name = "run-fmt";
        meta.description = "runs nix-fmt on the flake source";
        text = ''
          # Runs fmt from nixpkgs or local flake
            nix fmt --check "${self}"
        '';
      };
    };

}
