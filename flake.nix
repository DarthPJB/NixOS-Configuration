{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    nixinate.url = "github:matthewcroughan/nixinate";
    agenix.url = "github:ryantm/agenix";
    nixpkgs_2205.url = "github:nixos/nixpkgs/nixos-22.05";
    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    nixpkgs_stable.url = "github:nixos/nixpkgs/nixos-22.11";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = inputs@{ self, nixpkgs, nixos-hardware, agenix, parsecgaming, nixinate, nixpkgs_stable, nixpkgs_unstable, nixpkgs_2205 }: 
  {
      apps = nixinate.nixinate.x86_64-linux self;
        images = {
          pi = (self.nixosConfigurations.printerController.extendModules {
            modules = [
              "${nixpkgs_stable}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              {

              }
            ];
          }).config.system.build.sdImage;
        };
      nixosConfigurations = {
        printerController = nixpkgs_stable.lib.nixosSystem {
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
            ./config/configuration.nix
            ./config/environments/i3wm_darthpjb.nix
            ./config/environments/rtl-sdr.nix
            ./config/environments/pio.nix
            ./config/machines/terminalzero.nix
            ./config/environments/code.nix
            ./config/locale/tailscale.nix
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
            ./config/locale/hotel_wifi.nix
            ./config/configuration.nix
            ./config/environments/xfce.nix
            ./config/environments/rtl-sdr.nix
            ./config/machines/terminalmedia.nix
            ./config/environments/code.nix
            {
              environment.systemPackages =
                [ 
                  nixpkgs.legacyPackages.x86_64-linux.ffmpeg
                  parsecgaming.packages.x86_64-linux.parsecgaming 
                ];
            }
          ];
        };
        local-worker = nixpkgs_stable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./config/machines/local-worker.nix
            ./config/configuration.nix
            ./config/users/darthpjb.nix
            ./config/environments/neovim.nix
            ./config/environments/sshd.nix
            {
              _module.args.nixinate = {
                host = "192.168.122.69";
                sshUser = "John88";
                substituteOnTarget = true;
                hermetic = true;
                buildOn = "remote";
              };
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
            }
          ];
        };
        local-nas = nixpkgs_stable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./config/modifier_imports/zfs.nix
            ./config/machines/local-nas.nix
            ./config/configuration.nix
            ./config/users/darthpjb.nix
            ./config/environments/neovim.nix
            ./config/environments/sshd.nix
            {
              _module.args.nixinate = {
                host = "192.168.0.200";
                sshUser = "John88";
                substituteOnTarget = true;
                hermetic = true;
                buildOn = "remote";
              };
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
            }
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
                sshUser = "John88";
                substituteOnTarget = true;
                hermetic = true;
                buildOn = "remote";
              };
            }
          ];
        };

        LINDA = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./config/configuration.nix
            ./config/machines/LINDA.nix
            ./config/environments/i3wm_darthpjb.nix
            ./config/environments/steam.nix
            ./config/environments/code.nix
            ./config/environments/communications.nix
            ./config/environments/neovim.nix
            ./config/environments/cad_and_graphics.nix
            ./config/environments/blender.nix
            ./config/environments/3dPrinting.nix
            ./config/environments/audio_visual_editing.nix
            ./config/environments/general_fonts.nix
            ./config/environments/video_call_streaming.nix
            ./config/locale/tailscale.nix
            ./config/modifier_imports/bluetooth.nix
            ./config/modifier_imports/memtest.nix
            ./config/modifier_imports/cuda.nix
            ./config/modifier_imports/ipfs.nix
            ./config/modifier_imports/hosts.nix
            ./config/modifier_imports/zfs.nix
            ./config/modifier_imports/virtualisation-libvirtd.nix
            ./config/modifier_imports/arm-emulation.nix
            ./config/server_services/samba_server.nix
            {
            #networking.nameservers = [ "1.1.1.1" "8.8.8.8" "8.8.4.4" ];
              environment.systemPackages = [
                agenix.packages.x86_64-linux.default
                parsecgaming.packages.x86_64-linux.parsecgaming
              ];
            }
          ];
        };
      };
    };
}
