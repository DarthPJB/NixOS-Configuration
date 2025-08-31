{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    #nixinate.url = "path:/home/pokej/repo/DarthPJB/nixinate";
    nixinate.url = "github:DarthPJB/nixinate";
    nixinate.inputs.nixpkgs.follows = "nixpkgs_stable";
    secrix.url = "github:Platonic-Systems/secrix";

    #raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    #secrix.url = "path:/home/pokej/repo/platonic.systems/secrix";

    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs_stable.url = "github:nixos/nixpkgs/nixos-24.11";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
  # --------------------------------------------------------------------------------------------------
  outputs = { self, parsecgaming, nixos-hardware, secrix, nixinate, nixpkgs_unstable, nixpkgs_stable  }:
    let
      #      inherit (secrix) secrix;
      nixpkgs = nixpkgs_stable;
      un_nixpkgs = nixpkgs_unstable;
      pkgs = import nixpkgs_stable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      un_pkgs_arm = import nixpkgs_unstable {
        system = "aarch64-linux";
        config.allowUnfree = true;
      };
      un_pkgs = import nixpkgs_unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      # Define the function for a single configuration
      mkUncompressedSdImage = config:
        (config.extendModules {
          modules = [{ sdImage.compressImage = false; }];
        }).config.system.build.sdImage;

      # Define the function for a list of configurations
      mkUncompressedSdImages = configs:
        nixpkgs.lib.genAttrs
          (map (cfg: cfg.config.system.name) configs)
          (name: mkUncompressedSdImage (builtins.getAttr name self.nixosConfigurations));
    in
    {
      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
      apps.x86_64-linux = (nixinate.nixinate.x86_64-linux self).nixinate // ({ secrix = secrix.secrix self; });
      inherit un_pkgs;

      # -----------------------------------IMAGES-------------------------------------------------

      packages."aarch64-linux" = mkUncompressedSdImages [
        self.nixosConfigurations.print-controller
        self.nixosConfigurations.alpha-one
        self.nixosConfigurations.display-1
        self.nixosConfigurations.display-2
      ];


      local-worker-image = import "${nixpkgs_stable.cutPath}/nixos/lib/make-disk-image.nix"
        #local-image = import "${self}/lib/make-storeless-image.nix"
        rec {
          pkgs = un_pkgs;
          inherit (pkgs) lib;
          inherit (self.nixosConfigurations.local-worker) config;
          additionalPaths = [ ];
          name = "local.worker-image";
          format = "qcow2";
          onlyNixStore = false;
          label = "root_FS_nixos";
          partitionTableType = "efi";
          installBootLoader = true;
          touchEFIVars = true;
          diskSize = "auto";
          additionalSpace = "2048M";
          copyChannel = true;
          OVMF = pkgs.OVMF.fd;
        };
      # --------------------------------------------------------------------------------------------------
      nixosConfigurations = {
        # -----------------------------------ARM DEVICES-------------------------------------------------
        display-1 = un_nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          pkgs = un_pkgs_arm;
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            secrix.nixosModules.default
            nixos-hardware.nixosModules.raspberry-pi-4
            ./machines/display/1.nix
            ./users/darthpjb.nix
            ./configuration.nix
            ./locale/home_networks.nix
            {
              imports = [
                "${nixpkgs_stable}/nixos/modules/profiles/minimal.nix"
              ];
              disabledModules =
                [
                  "${nixpkgs_stable}/nixos/modules/profiles/all-hardware.nix"
                  "${nixpkgs_stable}/nixos/modules/profiles/base.nix"
                ];
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              #secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqeo8ceyMoi+SIRP5hhilbhJvFflphD0efolDCxccj9";
              system.stateVersion = "24.11";
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    port = "1108";
                    host = "10.88.128.230";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];

        };
        display-2 = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            secrix.nixosModules.default
            #nixos-hardware.nixosModules.raspberry-pi-4
            ./machines/display/2.nix
            ./users/darthpjb.nix
            ./configuration.nix
            ./locale/home_networks.nix
            {
              hardware.firmware = with nixpkgs.legacyPackages.aarch64-linux; [ raspberrypiWirelessFirmware ];
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              #secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqeo8ceyMoi+SIRP5hhilbhJvFflphD0efolDCxccj9";
              system.stateVersion = "24.11";
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    port = "1108";
                    #host = "10.88.128.10";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
        print-controller = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            secrix.nixosModules.default
            ./machines/print-controller
            ./users/darthpjb.nix
            ./configuration.nix
            ./locale/home_networks.nix
            ./server_services/klipper.nix
            {
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBqeo8ceyMoi+SIRP5hhilbhJvFflphD0efolDCxccj9";
              system.stateVersion = "24.11";
              networking.hostName = "print-controller";
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    port = "1108";
                    host = "10.88.128.10";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
        alpha-one = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            secrix.nixosModules.default
            nixos-hardware.nixosModules.raspberry-pi-3
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./machines/display-module
            ./users/darthpjb.nix
            ./configuration.nix
            ./locale/home_networks.nix
            ./modifier_imports/minimal.nix
            ./modifier_imports/pi-firmware.nix
            ./services/dynamic_domain_gandi.nix
            {
              imports = [
                "${nixpkgs_stable}/nixos/modules/profiles/headless.nix"
                "${nixpkgs_stable}/nixos/modules/profiles/minimal.nix"
              ];
              disabledModules =
                [
                  "${nixpkgs_stable}/nixos/modules/profiles/all-hardware.nix"
                  "${nixpkgs_stable}/nixos/modules/profiles/base.nix"
                ];
              services.kmscon = {
                autologinUser = "John88";
                extraConfig = ''
                  font-dpi=75
                '';
              };
              documentation.man.enable = false;
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkAJhTTF+WVWixTwIvEtRq5KdpjxPy4ptlcmFSEetrU";
              system.stateVersion = "24.11";
              _module.args =
                {
                  inherit self;
                  #inherit secrix;
                  nixinate = {
                    host = "alpha-two.johnbargman.net";
                    sshUser = "John88";
                    port = 1108;
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
        # -----------------------------------TERMINALS-------------------------------------------------
        terminal-zero = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            secrix.nixosModules.default
            ./modifier_imports/bluetooth.nix
            (import ./locale/home_networks.nix)
            (import ./environments/browsers.nix)
            (import ./configuration.nix)
            (import ./environments/i3wm.nix)
            (import ./environments/rtl-sdr.nix)
            (import ./environments/pio.nix)
            (import ./machines/terminal-zero)
            (import ./environments/code.nix)
            (import ./locale/tailscale.nix)
            nixos-hardware.nixosModules.lenovo-thinkpad-x220
            {
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    host = "10.88.128.20";
                    #host = "192.168.2.200";
                    port = 1108;
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGlV1inLX9o+Qyf/B3dp6xjb4f9bGisvkT6eFL/f8JIl";
              system.stateVersion = "24.11";
              nixpkgs.config.allowUnfree = true;
              environment.systemPackages =
                [
                  parsecgaming.packages.x86_64-linux.parsecgaming
                ];
            }
          ];
        };
        terminal-nx-01 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            secrix.nixosModules.default
            (import ./locale/hotel_wifi.nix)
            (import ./locale/home_networks.nix)
            (import ./environments/browsers.nix)
            (import ./configuration.nix)
            (import ./environments/i3wm_darthpjb.nix)
            (import ./machines/terminal-media)
            (import ./environments/code.nix)
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.nvidia.acceptLicense = true;
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOK07xnXN3O2v4EZ7YUzWSL5O+Uf2vM6+jzxROWzaTD5";
              system.stateVersion = "24.11";
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    host = "10.88.128.22";
                    port = "1108";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };

              environment.systemPackages =
                [
                  pkgs.ffmpeg
                  parsecgaming.packages.x86_64-linux.parsecgaming
                ];
            }
          ];
        };
        # -----------------------------------VIRTUALISED-------------------------------------------------
        local-worker = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            secrix.nixosModules.default
            "${nixpkgs}/nixos/modules/virtualisation/libvirtd.nix"
            ./machines/local-worker
            ./environments/blender.nix
            ./modifier_imports/cuda.nix
            ./configuration.nix
            ./users/darthpjb.nix
            ./environments/neovim.nix
            ./environments/emacs.nix
            ./environments/sshd.nix
            {
              nixpkgs.config.allowUnfree = true;
              nix.nixPath = [
                "nixpkgs=${nixpkgs_unstable}"
              ];
              system.stateVersion = "24.11";
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    host = "192.168.122.69";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
            }
          ];
        };
        # -----------------------------------HOME LAB-------------------------------------------------
        cortex-alpha = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            secrix.nixosModules.default
            ./machines/cortex-alpha
            ./configuration.nix
            ./environments/neovim.nix
            ./services/dynamic_domain_gandi.nix
            {
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWAilZq7Ocl8zm96sSAy+fRo8wt5mMVuRQmEQsk4MsB root@cortex-alpha";
              system.stateVersion = "24.11";
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    #host = "cortex-alpha.johnbargman.net"; #"10.88.128.1";
                    host = "10.88.128.1";
                    sshUser = "John88";
                    port = 1108;
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };

        data-storage = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          #  specialArgs = { inherit inputs; };
          modules = [
            secrix.nixosModules.default
            ./modifier_imports/zfs.nix
            ./machines/local-nas
            ./server_services/minio-insecure.nix
            ./configuration.nix
            ./users/darthpjb.nix
            ./environments/neovim.nix
            ./environments/emacs.nix
            ./environments/sshd.nix
            {
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINlCggPwFP5VX3YDA1iji0wxX8+mIzmrCJ1aHj9f1ofx";

              _module.args =
                {
                  inherit self;
                  nixinate = {
                    port = 1108;
                    host = "10.88.128.3";
                    sshUser = "John88";
                    substituteOnTarget = false;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };

        # In a mirror darkly
        alpha-two = un_nixpkgs.lib.nixosSystem
          {
            # In a mirror darkly
            pkgs = un_pkgs;
            system = "x86_64-linux";
            modules = [
              secrix.nixosModules.default
              ./configuration.nix
              ./machines/alpha-two
              (import ./locale/home_networks.nix)
              ./environments/i3wm_darthpjb.nix
              ./environments/steam.nix
              ./environments/code.nix
              ./environments/neovim.nix
              ./environments/communications.nix
              ./environments/emacs.nix
              ./environments/browsers.nix
              ./environments/mudd.nix
              ./environments/cad_and_graphics.nix
              ./environments/audio_visual_editing.nix
              ./environments/general_fonts.nix
              ./environments/video_call_streaming.nix
              ./environments/cloud_and_backup.nix
              ./locale/tailscale.nix
              ./environments/rtl-sdr.nix
              ./modifier_imports/bluetooth.nix
              ./modifier_imports/memtest.nix
              ./modifier_imports/hosts.nix
              ./modifier_imports/virtualisation-libvirtd.nix
              ./modifier_imports/arm-emulation.nix
              ./environments/sshd.nix
              ./modifier_imports/remote-builder.nix
              {
                environment.systemPackages =
                  [
                    parsecgaming.packages.x86_64-linux.parsecgaming
                  ];
                _module.args =
                  {
                    inherit self;
                    nixinate = {
                      #                      host = "192.168.2.200";
                      port = 1108;
                      sshUser = "John88";
                      substituteOnTarget = true;
                      hermetic = true;
                      buildOn = "local";
                    };
                  };
              }
            ];
          };
        LINDA = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          #specialArgs = { inherit inputs; };
          modules = [
            secrix.nixosModules.default
            ./configuration.nix
            ./machines/LINDA
            ./environments/i3wm_darthpjb.nix
            ./environments/steam.nix
            ./environments/code.nix
            ./environments/neovim.nix
            ./environments/communications.nix
            ./environments/emacs.nix
            ./environments/browsers.nix
            ./environments/mudd.nix
            ./environments/cad_and_graphics.nix
            ./environments/3dPrinting.nix
            ./environments/audio_visual_editing.nix
            ./environments/general_fonts.nix
            ./environments/video_call_streaming.nix
            ./environments/cloud_and_backup.nix
            ./locale/tailscale.nix
            ./environments/rtl-sdr.nix
            ./modifier_imports/bluetooth.nix
            ./modifier_imports/memtest.nix
            ./modifier_imports/hosts.nix
            ./modifier_imports/zfs.nix
            ./modifier_imports/virtualisation-libvirtd.nix
            ./modifier_imports/arm-emulation.nix
            ./environments/sshd.nix
            ./modifier_imports/cuda.nix
            ./modifier_imports/remote-builder.nix
            {
              environment.systemPackages = [
                parsecgaming.packages.x86_64-linux.parsecgaming
              ];
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDMfuVEzn9keN1iVk4rjJmB07+/ynTMaZCKPvbaZ1cF6";
              system.stateVersion = "24.11";
              nixpkgs.config.allowUnfree = true;
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    host = "LINDACORE.johnbargman.net";
                    port = 1108;
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "remote";
                  };
                };
            }
          ];
        };
        # -----------------------------------REMOTE SYSTEMS-------------------------------------------------
        remote-worker = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            secrix.nixosModules.default
            ./configuration.nix
            ./machines/remote-worker
            ./locale/tailscale.nix
            ./server_services/nextcloud.nix
            # ./server_services/hedgedoc.nix
            ./services/dynamic_domain_gandi.nix
            {
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPPSFI0IBhhtyMRcMtvHmMBbwklzXiOXw0OPVD3SEC+M";
              system.stateVersion = "24.11";
              imports = [
                "${nixpkgs}/nixos/modules/virtualisation/openstack-config.nix"
              ];
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    port = 1108;
                    host = "remote-worker.johnbargman.net";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
        storage-array = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            secrix.nixosModules.default
            ./modifier_imports/zfs.nix
            ./machines/storage-array
            ./configuration.nix
            ./users/darthpjb.nix
            ./environments/neovim.nix
            ./environments/emacs.nix
            ./environments/code.nix
            ./environments/neovim.nix
            ./environments/sshd.nix
            ./environments/audio_visual_editing.nix
            ./services/dynamic_domain_gandi.nix
            {
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMfb/Bbr0PaFDyO92q+GXHHXTAlTYR4uSLm0jivou4IB";
              system.stateVersion = "24.11";
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    host = "10.88.127.4";
                    sshUser = "John88";
                    port = 1108;
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
        remote-builder = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            secrix.nixosModules.default
            ./users/darthpjb.nix
            ./modifier_imports/flakes.nix
            ./environments/sshd.nix
            ./environments/tools.nix
            ./services/dynamic_domain_gandi.nix
            ./services/github_runners.nix
            ./machines/remote-builder
            {
              secrix.defaultEncryptKeys = { John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ]; };
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7Owkd/9PC7j/L5PbPXrSMx0Aw/1owIoCsfp7+5OKek";
              system.stateVersion = "24.11";
              networking.hostName = "remote-builder";
              imports = [
                "${nixpkgs}/nixos/modules/virtualisation/openstack-config.nix"
              ];
              _module.args =
                {
                  inherit self;
                  nixinate = {
                    port = 1108;
                    host = "remote-builder.johnbargman.net";
                    sshUser = "John88";
                    buildOn = "remote";
                  };
                };
            }
          ];
        };
        # -------------------------------------------------------------------------------------------------------
      };
    };
}
