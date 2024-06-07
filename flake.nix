{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    nixinate.url = "github:matthewcroughan/nixinate";
    secrix.url = "github:Platonic-Systems/secrix";
    #secrix.url = "path:/home/pokej/repo/platonic.systems/secrix";

    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs_stable.url = "github:nixos/nixpkgs/nixos-24.05";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = { self, nixpkgs_stable, ... }@inputs:
    let
      inherit (inputs.secrix) secrix;
      nixpkgs = inputs.nixpkgs_stable;
      pkgs = import inputs.nixpkgs_stable {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
          cudaSupport = true;
          cudnnSupport = true;
        };
      };
      un_pkgs = import inputs.nixpkgs_unstable {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
          cudaSupport = true;
          cudnnSupport = true;
        };
      };
    in
    {

      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
      apps.x86_64-linux = (inputs.nixinate.nixinate.x86_64-linux inputs.self).nixinate // ({ secrix = secrix self; });
      un_pkgs = un_pkgs;
      images = {
        pi-print-controller = (self.nixosConfigurations.pi-print-controller.extendModules {
          modules = [
            inputs.secrix.nixosModules.default
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ];
        }).config.system.build.sdImage;
        local-worker = import "${inputs.nixpkgs.cutPath}/nixos/lib/make-disk-image.nix"
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
      };
      nixosConfigurations = {
        pi-print-controller = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            #inputs.secrix.nixosModules.default
            ./machines/rPI.nix
            ./users/darthpjb.nix
            ./locale/home_networks.nix
            ./server_services/klipper.nix
          ];
        };
        pi-display-module = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            inputs.secrix.nixosModules.default
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./machines/rPI.nix
            ./users/darthpjb.nix
            ./configuration.nix
            ./locale/home_networks.nix
            ./environments/browsers.nix
            ./environments/i3wm_darthpjb.nix
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
              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "192.168.0.115";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
        Terminal-zero = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.secrix.nixosModules.default
            (import ./environments/browsers.nix)
            (import ./configuration.nix)
            (import ./environments/i3wm_darthpjb.nix)
            (import ./environments/rtl-sdr.nix)
            (import ./environments/pio.nix)
            (import ./machines/terminalzero.nix)
            (import ./environments/code.nix)
            (import ./locale/tailscale.nix)
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220
            {
              environment.systemPackages =
                [
                  #parsecgaming.packages.x86_64-linux.parsecgaming 
                ];
            }
          ];
        };
        Terminal-media = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.secrix.nixosModules.default
            (import ./locale/hotel_wifi.nix)
            (import ./environments/browsers.nix)
            (import ./configuration.nix)
            (import ./environments/i3wm_darthpjb.nix)
            (import ./environments/rtl-sdr.nix)
            (import ./machines/terminalmedia.nix)
            (import ./environments/code.nix)
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.nvidia.acceptLicense = true;

              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "192.168.0.50";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
              environment.systemPackages =
                [
                  pkgs.ffmpeg
                ];
            }
          ];
        };
        local-worker = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.secrix.nixosModules.default
            "${nixpkgs}/nixos/modules/virtualisation/libvirtd.nix"
            ./machines/local-worker.nix
            ./environments/blender.nix
            ./modifier_imports/cuda.nix
            ./configuration.nix
            ./users/darthpjb.nix
            ./environments/neovim.nix
            ./environments/emacs.nix
            ./environments/sshd.nix
            {
              nix.nixPath = [
                "nixpkgs=${inputs.nixpkgs_unstable}"
              ];
              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "192.168.122.69";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "remote";
                  };
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
            inputs.secrix.nixosModules.default
            ./modifier_imports/zfs.nix
            ./machines/local-nas.nix
            ./configuration.nix
            ./users/darthpjb.nix
            ./environments/neovim.nix
            ./environments/emacs.nix
            ./environments/sshd.nix
            {
              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "192.168.0.206";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "remote";
                  };
                };
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
            }
          ];
        };
        RemoteWorker-2 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.secrix.nixosModules.default
            ./configuration.nix
            ./machines/ethan-net.nix
            {
              networking.firewall.allowedTCPPorts = [ 22000 ];
              networking.firewall.allowedUDPPorts = [ 22000 21027 ];
              services = {
                syncthing = {

                  guiAddress = "127.0.0.1:8384";


                  openDefaultPorts = true;
                  enable = true;
                  user = "syncthing";
                  dataDir = "/bulk-storage/syncthing";
                  configDir = "/bulk-storage/syncthing/.config/syncthing";
                  overrideDevices = true; # overrides any devices added or deleted through the WebUI
                  overrideFolders = true; # overrides any folders added or deleted through the WebUI
                  settings = {
                    extraOptions.gui = {
                      user = "DarthPJB";
                      password = "THIS_PASS_WORD_IS_HARD?";
                    };
                    devices = {
                      "local-nas" = { id = "YSM4GLR-RVNNKB5-56ICTQG-7WJSIVC-VAYUBIO-ANZCL5W-3JIVSUY-IECJGQQ"; };
                      "remote-worker-1" = { id = "IBQ4OX7-QB5ON3R-WITXQ2A-IWHSM4Z-E4OES2K-RHCBUQU-YXXCNTX-TUDD5QE"; };
                    };
                    folders = {
                      "obisidan-archive" = {
                        # Name of folder in Syncthing, also the folder ID
                        id = "hb36j-r9ffv";
                        path = "/bulk-storage/syncthing/obsidian-archive"; # Which folder to add to Syncthing
                        devices = [ "remote-worker-1" "local-nas" ]; # Which devices to share the folder with
                      };
                      "NAS-ARCHIVE" = {
                        # Name of folder in Syncthing, also the folder ID
                        id = "gtpsy-rfgv5";
                        path = "/bulk-storage/syncthing/remote.worker"; # Which folder to add to Syncthing
                        devices = [ "remote-worker-1" "local-nas" ]; # Which devices to share the folder with
                      };
                    };

                  };
                };
              };
              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "149.5.115.141";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "remote";
                  };
                };
            }
          ];
        };
        RemoteWorker-1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.secrix.nixosModules.default
            ./configuration.nix
            ./machines/openstack.nix
            ./locale/tailscale.nix
            ./server_services/nextcloud.nix
            ./server_services/hedgedoc.nix

            {
              imports = [
                "${nixpkgs}/nixos/modules/virtualisation/openstack-config.nix"
              ];
              secrix.hostPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPPSFI0IBhhtyMRcMtvHmMBbwklzXiOXw0OPVD3SEC+M";
              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "193.16.42.101";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "remote";
                  };
                };
            }
          ];
        };


        LINDA = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.secrix.nixosModules.default
            ./configuration.nix
            ./machines/LINDACORE.nix
            ./environments/i3wm_darthpjb.nix
            ./environments/steam.nix
            ./environments/code.nix
            ./environments/communications.nix
            ./environments/neovim.nix
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
            ./modifier_imports/bluetooth.nix
            ./modifier_imports/memtest.nix
            ./modifier_imports/cuda.nix
            ./modifier_imports/hosts.nix
            ./modifier_imports/zfs.nix
            ./modifier_imports/virtualisation-libvirtd.nix
            ./modifier_imports/arm-emulation.nix
            ./environments/sshd.nix
            ./modifier_imports/cuda.nix
            ./modifier_imports/remote-builder.nix
            {
              _module.args =
                {
                  self = self;
                };
              environment.systemPackages =
                let
                  system = "x86_64-linux";
                in
                [
                  un_pkgs.vivaldi
                  #parsecgaming.packages.x86_64-linux.parsecgaming
                ];
            }
          ];
        };
        LINDACLONE = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.secrix.nixosModules.default
            ./configuration.nix
            ./users/l33.nix
            ./machines/LINDA-CLONE.nix
            ./environments/i3wm_darthpjb.nix
            ./environments/steam.nix
            ./environments/code.nix
            ./environments/communications.nix
            ./environments/neovim.nix
            ./environments/emacs.nix
            ./environments/browsers.nix
            ./environments/mudd.nix
            ./environments/cloud_and_backup.nix
            ./environments/cad_and_graphics.nix
            ./environments/3dPrinting.nix
            ./environments/audio_visual_editing.nix
            ./environments/general_fonts.nix
            ./environments/video_call_streaming.nix
            ./locale/tailscale.nix
            ./modifier_imports/bluetooth.nix
            ./modifier_imports/memtest.nix
            ./modifier_imports/hosts.nix
            ./modifier_imports/zfs.nix
            ./modifier_imports/virtualisation-libvirtd.nix
            ./modifier_imports/arm-emulation.nix
            ./environments/sshd.nix
            ./modifier_imports/remote-builder.nix
            ./modifier_imports/cuda.nix
            {
              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "192.168.0.93";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "remote";
                  };
                };
              nixpkgs.config.allowUnfree = true;
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
              environment.systemPackages =
                [
                  un_pkgs.vivaldi
                  #  parsecgaming.packages.x86_64-linux.parsecgaming
                ];
            }
          ];
        };
      };
    };
}
