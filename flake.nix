{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    nixinate.url = "github:matthewcroughan/nixinate";
    agenix.url = "github:ryantm/agenix";
    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    #    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = inputs@{ self, nixos-hardware, agenix, parsecgaming, nixinate, nixpkgs_unstable }:
    let
      nixpkgs = nixpkgs_unstable;
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      apps.x86_64-linux = (inputs.nixinate.nixinate.x86_64-linux inputs.self).nixinate;
      images = {
        pi-print-controller = (self.nixosConfigurations.pi-print-controller.extendModules {
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ];
        }).config.system.build.sdImage;

        pi-display-module = (self.nixosConfigurations.pi-display-module.extendModules {
          modules = [

          ];
        }).config.system.build.sdImage;

        local-worker = import "${self}/lib/make-storeless-image.nix"
          #local-image = import "${inputs.nixpkgs.outPath}/nixos/lib/make-disk-image.nix" 
          rec {
            pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
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
            #diskSize = "4096";
            additionalSpace = "2048M";
            copyChannel = true;
            OVMF = pkgs.OVMF.fd;
          };
      };
      nixosConfigurations = {
        pi-print-controller = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./config/machines/rPI.nix
            ./config/users/darthpjb.nix
            ./config/locale/home_networks.nix
            ./config/server_services/klipper.nix
          ];
        };
        pi-display-module = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./config/machines/rPI.nix
            ./config/users/darthpjb.nix
            ./config/configuration.nix
            ./config/locale/home_networks.nix
            ./config/environments/browsers.nix
            ./config/environments/i3wm_darthpjb.nix
            {
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
              fileSystems."/home/pokej/obisidan-archive" =
                {
                  device = "/dev/disk/by-uuid/8c501c5c-9fbe-4e9d-b8fc-fbf2987d80ca";
                  fsType = "ext4";
                };
              services.xserver.displayManager.sddm.enable = nixpkgs.lib.mkForce false;
              services.xserver.displayManager.lightdm.enable = nixpkgs.lib.mkForce true;
              hardware.bluetooth.enable = false;
              nixpkgs.config.allowUnfree = true;
              _module.args.nixinate = {
                host = "192.168.0.115";
                sshUser = "John88";
                substituteOnTarget = true;
                hermetic = true;
                buildOn = "local";
              };
            }

          ];
        };
        Terminal-zero = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import ./config/environments/browsers.nix)
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
            (import ./config/environments/browsers.nix)
            (import ./config/configuration.nix)
            (import ./config/environments/xfce.nix)
            (import ./config/environments/rtl-sdr.nix)
            (import ./config/machines/terminalmedia.nix)
            (import ./config/environments/code.nix)
            {
              environment.systemPackages =
                [
                  nixpkgs.legacyPackages.x86_64-linux.ffmpeg
                  parsecgaming.packages.x86_64-linux.parsecgaming
                ];
            }
          ];
        };
        local-worker = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            "${nixpkgs}/nixos/modules/virtualisation/libvirtd.nix"
            ./config/machines/local-worker.nix
            ./config/environments/blender.nix
            ./config/modifier_imports/cuda.nix
            ./config/configuration.nix
            ./config/users/darthpjb.nix
            ./config/environments/neovim.nix
            ./config/environments/sshd.nix
            {
              nix.nixPath = [
                "nixpkgs=${inputs.nixpkgs}"
              ];
              _module.args.nixinate = {
                host = "192.168.122.69";
                sshUser = "John88";
                substituteOnTarget = true;
                hermetic = true;
                buildOn = "local";
              };
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
            }
          ];
        };
        local-nas = nixpkgs.lib.nixosSystem {
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
                host = "192.168.0.206";
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
        obs-box = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [
              ./config/configuration.nix
              ./config/machines/obs-box.nix
              ./config/environments/i3wm_darthpjb.nix
              ./config/environments/video_call_streaming.nix
              ./config/modifier_imports/zfs.nix
              {
                networking.firewall.allowedTCPPorts = [ 6666 8080 6669 ];
                networking.firewall.allowedUDPPorts = [ 6666 ];
                _module.args.nixinate = {
                  host = "192.168.0.186";
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
            ./config/environments/browsers.nix
            ./config/environments/mudd.nix
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
            ./config/modifier_imports/hosts.nix
            ./config/modifier_imports/zfs.nix
            ./config/modifier_imports/virtualisation-libvirtd.nix
            ./config/modifier_imports/arm-emulation.nix
            #            ./config/server_services/samba_server.nix
            {
              networking.firewall.allowedTCPPorts = [ 6666 8080 6669 ];
              networking.firewall.allowedUDPPorts = [ 6666 ];
              #networking.nameservers = [ "1.1.1.1" "8.8.8.8" "8.8.4.4" ];

              environment.systemPackages =
                let
                  system = "x86_64-linux";
                  pkgs_unstable = import inputs.nixpkgs_unstable {
                    inherit system;
                    config.allowUnfree = true;
                  };
                in
                [
                  pkgs_unstable.vivaldi
                  agenix.packages.x86_64-linux.default
                  parsecgaming.packages.x86_64-linux.parsecgaming
                ];
            }
          ];
        };
      };
    };
}
