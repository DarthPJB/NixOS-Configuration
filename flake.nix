{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    nixinate.url = "github:matthewcroughan/nixinate";
    secrix.url = "github:Platonic-Systems/secrix";
    #secrix.url = "path:/home/pokej/repo/platonic.systems/secrix";

    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs_stable.url = "github:nixos/nixpkgs/nixos-24.11";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
# --------------------------------------------------------------------------------------------------
  outputs = { self, ... }@inputs:
    let
      inherit (inputs.secrix) secrix;
      nixpkgs = inputs.nixpkgs_stable;
      pkgs = import inputs.nixpkgs_stable {
        system = "x86_64-linux";
      };

      pkgs_arm = import inputs.nixpkgs_stable {
        system = "aarch64-linux";
      };

      un_pkgs = import inputs.nixpkgs_unstable {
        system = "x86_64-linux";
      };
    in
    {
      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
      apps.x86_64-linux = (inputs.nixinate.nixinate.x86_64-linux inputs.self).nixinate // ({ secrix = secrix self; });
      inherit un_pkgs;

# -----------------------------------IMAGES-------------------------------------------------

      images = {
        pi-print-controller = (self.nixosConfigurations.pi-print-controller.extendModules {
          modules = [
            inputs.secrix.nixosModules.default
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ];
        }).config.system.build.sdImage;
        display-module = (self.nixosConfigurations.display-module.extendModules {
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            { config.system.build.sdImage.compressImage = false; }
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
# --------------------------------------------------------------------------------------------------
      nixosConfigurations = {

# -----------------------------------ARM DEVICES-------------------------------------------------
        pi-print-controller = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            #inputs.secrix.nixosModules.default
            ./machines/rPI.nix
            ./users/darthpjb.nix
            ./locale/home_networks.nix
            ./server_services/klipper.nix
            {
              networking.hostName = "printcontroller";
            }
          ];
        };
        display-module = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            inputs.secrix.nixosModules.default
            #inputs.nixos-hardware.nixosModules.raspberry-pi-3
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./machines/display-module.nix
            ./users/darthpjb.nix
            ./configuration.nix
            ./locale/home_networks.nix
            ./environments/browsers.nix
            ./environments/i3wm.nix
            { }
          ];
        };
# -----------------------------------TERMINALS-------------------------------------------------
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
# -----------------------------------VIRTUALISED-------------------------------------------------
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
                    #                    substituteOnTarget = true;
                    #                    hermetic = true;
                    buildOn = "local";
                  };
                };
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
            }
          ];
        };
# -----------------------------------HOME LAB-------------------------------------------------
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
                    #                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
              services.openssh.ports = [ 22 ];
              networking.firewall.allowedTCPPorts = [ 22 ];
            }
          ];
        };
LINDA = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.secrix.nixosModules.default
            #            determinate.nixosModules.default
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
            ./modifier_imports/hosts.nix
            ./modifier_imports/zfs.nix
            ./modifier_imports/virtualisation-libvirtd.nix
            ./modifier_imports/arm-emulation.nix
            ./environments/sshd.nix
            ./modifier_imports/cuda.nix
            ./modifier_imports/remote-builder.nix
            {
              environment.systemPackages =
                [
                  pkgs.monero-gui
                ];
              _module.args =
                {
                  self = self;
                };
            }
          ];
        };
# -----------------------------------REMOTE SYSTEMS-------------------------------------------------
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
                    host = "181.215.32.40";
                    sshUser = "John88";
                    #                   substituteOnTarget = true;
                    #                   hermetic = true;
                    buildOn = "local";
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
            #            determinate.nixosModules.default
            {

              nixpkgs.config.permittedInsecurePackages = [
                "nextcloud-27.1.11"
              ];

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
                    #                    substituteOnTarget = true;
                    #                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
# -------------------------------------------------------------------------------------------------------
      };
    };
}
