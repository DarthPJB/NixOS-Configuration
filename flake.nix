{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    deadnix = { url = "github:astro/deadnix"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    hyprland.url = "github:hyprwm/Hyprland";
    lint-utils = { url = "github:homotopic/lint-utils"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    nixinate = { url = "github:DarthPJB/nixinate"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
    secrix.url = "github:Platonic-Systems/secrix";
    sl = {
      url = "github:pinktrink/sl/a613b55b692304f8e020af8889ff996c0918fa7d";
      flake = false;
    };
    nixpkgs_stable.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs_legacy.url = "github:nixos/nixpkgs?ref=nixos-23.05";
    nixpkgs_unstable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nix-mcp-servers.url = "github:cameronfyfe/nix-mcp-servers";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    agent-files = {
      url = "path:/speed-storage/opencode";
      flake = false;
    };
  };
  outputs = { self, deadnix, determinate, hyprland, lint-utils, nixinate, nix-mcp-servers, nixos-hardware, nixpkgs_legacy, nixpkgs_stable, nixpkgs_unstable, parsecgaming, secrix, sl, agent-files }: let
    flake_pkgs = nixpkgs_stable.legacyPackages.x86_64-linux;
    lib = nixpkgs_stable.lib;
    globalArgs = {
      inherit self;
      sl = sl;
      agentFiles = agent-files;
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
      nixpkgs_unstable.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          "${nixpkgs_unstable}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          "${nixpkgs_unstable}/nixos/modules/profiles/minimal.nix"
          hardware
        ] ++ commonModules ++ extraModules ++ (if dt then [ determinate.nixosModules.default ] else [ ]) ++ [
          ./machines/${name}
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
    formatter."x86_64-linux" = flake_pkgs.nixpkgs-fmt;
    apps."x86_64-linux" = { secrix = secrix.secrix self; } // (nixinate.lib.genDeploy.x86_64-linux self) // {
      deploy-all = {
        type = "app";
        meta.description = "itsa make the pizza delivery";
        program = lib.getExe (flake_pkgs.writeShellApplication {
          name = "deploy-all";
          runtimeInputs = with flake_pkgs; [ nix jq figlet ];
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
        ];
      };

      display-1 = mkAarch64 "display/1.nix" "display-1" {
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOxb+iAm5nTcC3oRsMIcxcciKRj8VnGpp1JIAdGVTZU";
        host = "10.88.127.41";
        extraModules = [ ./users/build.nix ];
      };
      display-2 = mkAarch64 "display/2.nix" "display-2" {
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPcOQZcWlN4XK5OYjI16PM/BWK/8AwKePb1ca/ZRuR1p";
        host = "10.88.127.42";
        extraModules = [ ./users/build.nix ];
      };
      print-controller = mkAarch64 "print-controller" "print-controller" {
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqeo8ceyMoi+SIRP5hhilbhJvFflphD0efolDCxccj9";
        host = "10.88.127.30";
        hardware = nixos-hardware.nixosModules.raspberry-pi-3;
        extraModules = [ ./server_services/klipper.nix ];
      };
      display-0 = mkAarch64 "display/0.nix" "display-0" {
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkAJhTTF+WVWixTwIvEtRq5KdpjxPy4ptlcmFSEetrU";
        host = "alpha-one.johnbargman.net";
        hardware = nixos-hardware.nixosModules.raspberry-pi-3;
        extraModules = [ ./modifier_imports/minimal.nix ./modifier_imports/pi-firmware.nix ];
      };

      terminal-zero = mkX86_64 "terminal-zero" "terminal-zero" {
        dt = true;
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGlV1inLX9o+Qyf/B3dp6xjb4f9bGisvkT6eFL/f8JIl";
        host = "10.88.127.20";
        extraModules = [
          ./modifier_imports/central-builder.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x220
          { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; }
        ];
      };
      terminal-nx-01 = mkX86_64 "terminal-media" "terminal-nx-01" {
        dt = true;
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOK07xnXN3O2v4EZ7YUzWSL5O+Uf2vM6+jzxROWzaTD5";
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

      local-worker = mkX86_64 "local-worker" "local-worker" {
        host = "10.88.127.89";
        extraModules = [ "${nixpkgs_stable}/nixos/modules/virtualisation/libvirtd.nix" ];
      };

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
        host = "10.88.127.88";
        buildOn = "remote";
        extraModules = [ ./users/build.nix { environment.systemPackages = [ parsecgaming.packages.x86_64-linux.parsecgaming ]; } ];
      };

      remote-worker = mkX86_64 "remote-worker" "remote-worker" {
        dt = false;
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPPSFI0IBhhtyMRcMtvHmMBbwklzXiOXw0OPVD3SEC+M";
        host = "10.88.127.50";
      };
      storage-array = mkX86_64 "storage-array" "storage-array" {
        dt = true;
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMfb/Bbr0PaFDyO92q+GXHHXTAlTYR4uSLm0jivou4IB";
        host = "10.88.127.4";
      };
      remote-builder = mkX86_64 "remote-builder" "remote-builder" {
        dt = false;
        hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7Owkd/9PC7j/L5PbPXrSMx0Aw/1owIoCsfp7+5OKek";
        host = "10.88.127.51";
      };
    };

    checks."x86_64-linux".deadnix = flake_pkgs.writeShellApplication {
      name = "run-deadnix";
      meta.description = "runs deadnix on the flake source";
      text = ''
        nix run ${deadnix}#deadnix "${self}"
      '';
    };

    checks."x86_64-linux".nixpkgs-fmt = lint-utils.linters.x86_64-linux.nixpkgs-fmt { src = self; };
  };
}