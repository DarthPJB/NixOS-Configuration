{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    #nixinate.url = "path:/home/pokej/repo/DarthPJB/nixinate";
    nixinate.url = "github:matthewcroughan/nixinate";
    secrix.url = "github:Platonic-Systems/secrix";

    #raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
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
        config.allowUnfree = true;
      };

      pkgs_arm = import inputs.nixpkgs_stable {
        system = "aarch64-linux";
        config.allowUnfree = true;
      };

      un_pkgs = import inputs.nixpkgs_unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    in
    {
      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
      apps.x86_64-linux = (inputs.nixinate.nixinate.x86_64-linux inputs.self).nixinate // ({ secrix = secrix self; });
      inherit un_pkgs;

      # -----------------------------------IMAGES-------------------------------------------------

      print-controller-image = (self.nixosConfigurations.print-controller.extendModules
        {
          modules = [{ sdImage.compressImage = false; }];
        }).config.system.build.sdImage;
      display-module-image = (self.nixosConfigurations.display-module.extendModules
        {
          modules = [{ sdImage.compressImage = false; }];
        }).config.system.build.sdImage;

      local-worker-image = import "${inputs.nixpkgs.cutPath}/nixos/lib/make-disk-image.nix"
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
        print-controller = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            inputs.secrix.nixosModules.default
            ./machines/print-controller
            ./users/darthpjb.nix
            ./configuration.nix
            ./locale/home_networks.nix
            ./server_services/klipper.nix
            {
              system.stateVersion = "24.11";
              networking.hostName = "printcontroller";
              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "192.168.0.40";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
        display-module = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            inputs.secrix.nixosModules.default
            inputs.nixos-hardware.nixosModules.raspberry-pi-3
            #inputs.raspberry-pi-nix.nixosModules.raspberry-pi
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./machines/display-module
            ./users/darthpjb.nix
            ./configuration.nix
            ./locale/home_networks.nix
            ./environments/browsers.nix
            ./environments/code.nix
            ./environments/i3wm.nix
            ./modifier_imports/pi-firmware.nix

            # Just for testing
            (import ./environments/rtl-sdr.nix)
            {
              system.stateVersion = "24.11";
              _module.args =
                {
                  self = self;
                  nixinate = {
                    #                    host = "192.168.0.115";
                    host = "192.168.0.73";
                    sshUser = "John88";
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
            inputs.secrix.nixosModules.default
            ./modifier_imports/bluetooth.nix
            (import ./environments/browsers.nix)
            (import ./configuration.nix)
            (import ./environments/i3wm_darthpjb.nix)
            (import ./environments/rtl-sdr.nix)
            (import ./environments/pio.nix)
            (import ./machines/terminal-zero)
            (import ./environments/code.nix)
            (import ./locale/tailscale.nix)
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220
            {
              _module.args =
                {
                  self = self;
                  nixinate = {
                    #host = "192.168.0.187";
                    host = "192.168.2.150";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
              networking.firewall.allowedTCPPorts = [ 53 ];

              environment.systemPackages =
                [
                  #parsecgaming.packages.x86_64-linux.parsecgaming 
                ];
            }
          ];
        };
        terminal-media = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.secrix.nixosModules.default
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
            ./machines/local-worker
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
        storage-array = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.secrix.nixosModules.default
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
            {
              nixpkgs.config.allowUnfree = true;
              _module.args =
                {
                  self = self;
                  nixinate = {
                    host = "192.168.0.16";
                    sshUser = "John88";
                    substituteOnTarget = true;
                    hermetic = true;
                    buildOn = "local";
                  };
                };
            }
          ];
        };
        local-nas = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.secrix.nixosModules.default
            ./modifier_imports/zfs.nix
            ./machines/local-nas
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
                    buildOn = "local";
                  };
                };
            }
          ];
        };

        alpha-two = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.secrix.nixosModules.default
            ./configuration.nix
            ./machines/alpha-two
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
            # ./modifier_imports/zfs.nix
            ./modifier_imports/virtualisation-libvirtd.nix
            ./modifier_imports/arm-emulation.nix
            ./environments/sshd.nix
            #  ./modifier_imports/cuda.nix
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
        LINDA = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.secrix.nixosModules.default
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
            ./machines/ethan-net
            {
              networking.firewall.allowedTCPPorts = [ 22000 ];
              networking.firewall.allowedUDPPorts = [ 22000 21027 ];

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
