{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    nixinate.url = "github:matthewcroughan/nixinate";
    agenix.url = "github:ryantm/agenix";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs_stable.url = "github:nixos/nixpkgs/nixos-22.11";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = inputs@{ self, nixpkgs, nixos-hardware, agenix, parsecgaming, nixinate, nixpkgs_stable }: {
      apps = nixinate.nixinate.x86_64-linux self;
        images = {
          pi = (self.nixosConfigurations.pi.extendModules {
            modules = [
              "${nixpkgs_stable}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              {
                
                #nixpkgs.config.allowUnsupportedSystem = true;
                #nixpkgs.crossSystem.system = "aarch64-linux";
              }
            ];
          }).config.system.build.sdImage;
        };
      nixosConfigurations = {
        pi = nixpkgs_stable.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./config/machines/rPI.nix
            ./config/users/darthpjb.nix
            ./config/locale/home_networks.nix
            ./config/server_services/klipper.nix
          ];
        };
        Terminal-zero = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import ./config/locale/hotel_wifi.nix)
            (import ./config/configuration.nix)
            (import ./config/environments/i3wm_darthpjb.nix)
            (import ./config/environments/rtl-sdr.nix)
            (import ./config/environments/pio.nix)
            (import ./config/machines/terminalzero.nix)
            (import ./config/environments/code.nix)
            (import ./config/locale/tailscale.nix)
            nixos-hardware.nixosModules.lenovo-thinkpad-x220
            {
              environment.systemPackages =
                [ parsecgaming.packages.x86_64-linux.parsecgaming ];
            }
          ];
        };
        Terminal-media = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import ./config/locale/hotel_wifi.nix)
            (import ./config/configuration.nix)
            (import ./config/environments/xfce.nix)
            (import ./config/environments/rtl-sdr.nix)
            (import ./config/machines/terminalmedia.nix)
            (import ./config/environments/code.nix)
            {
              environment.systemPackages =
                [ parsecgaming.packages.x86_64-linux.parsecgaming ];
            }

          ];
        };
        Terminal-VM1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import ./config/configuration.nix)
            (import ./config/environments/i3wm_darthpjb.nix)
            (import ./config/locale/tailscale.nix)
            (import ./config/machines/VirtualBox.nix)
          ];
        };
        Terminal-VM2 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import ./config/configuration.nix)
            (import ./config/environments/i3wm_darthpjb.nix)
            (import ./config/machines/hyperv.nix)
          ];
        };

        RemoteWorker-1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            agenix.nixosModules.default
            ./config/configuration.nix
            ./config/machines/openstack.nix
            ./config/locale/tailscale.nix
            ./config/server_services/nextcloud.nix
            ./config/server_services/syncthing_server.nix
            {
              imports = [
                "${nixpkgs}/nixos/modules/virtualisation/openstack-config.nix"
              ];
              _module.args.nixinate = {
                host = "193.16.42.101";
                sshUser = "nixos";
                substituteOnTarget = true;
                hermetic = true;
                buildOn = "remote";
              };
            }
          ];
        };

        LINDA = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import ./config/configuration.nix)
            (import ./config/machines/LINDA.nix)
            (import ./config/environments/i3wm_darthpjb.nix)
            (import ./config/environments/steam.nix)
            (import ./config/environments/code.nix)
            (import ./config/environments/communications.nix)
            (import ./config/environments/neovim.nix)
            (import ./config/environments/cad_and_graphics.nix)
            (import ./config/environments/3dPrinting.nix)
            (import ./config/environments/audio_visual_editing.nix)
            (import ./config/environments/general_fonts.nix)
            (import ./config/environments/video_call_streaming.nix)
            (import ./config/locale/tailscale.nix)
            (import ./config/modifier_imports/bluetooth.nix)
            (import ./config/modifier_imports/memtest.nix)
            (import ./config/modifier_imports/cuda.nix)
            (import ./config/modifier_imports/ipfs.nix)
            (import ./config/modifier_imports/hosts.nix)
            (import ./config/modifier_imports/virtualisation-virtualbox.nix)
            (import ./config/modifier_imports/arm-emulation.nix)
            {
              environment.systemPackages = [
                agenix.packages.x86_64-linux.default
                nixpkgs_stable.legacyPackages.x86_64-linux.gimp-with-plugins
                parsecgaming.packages.x86_64-linux.parsecgaming
              ];
            }
          ];
        };
      };
    };
}
