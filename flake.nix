{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    nixinate.url = "github:matthewcroughan/nixinate";
    agenix.url = "github:ryantm/agenix";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = { self, nixpkgs, nixos-hardware, agenix, parsecgaming, nixinate}:
  {
    apps = nixinate.nixinate.x86_64-linux self;
    nixosConfigurations =
    {
      Terminal-zero = nixpkgs.lib.nixosSystem
      {
        system = "x86_64-linux";
        modules =
        [
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
            [   
              parsecgaming.packages.x86_64-linux.parsecgaming
            ];
          }
        ];
      };
      Terminal-VM1 = nixpkgs.lib.nixosSystem
      {
        system = "x86_64-linux";
        modules =
        [
          (import ./config/configuration.nix)
          (import ./config/environments/i3wm_darthpjb.nix)
          (import ./config/locale/tailscale.nix)
          (import ./config/machines/VirtualBox.nix)
        ];
      };
      Terminal-VM2 = nixpkgs.lib.nixosSystem
      {
        system = "x86_64-linux";
        modules =
        [
          (import ./config/configuration.nix)
          (import ./config/environments/i3wm_darthpjb.nix)
          (import ./config/machines/hyperv.nix)
        ];
      };

      RemoteWorker-1 = nixpkgs.lib.nixosSystem 
      {
        system = "x86_64-linux";
        modules = [ 
          (import ./config/configuration.nix)
          (import ./config/machines/openstack.nix)
          (import ./config/locale/tailscale.nix)
          (import ./config/server_services/nextcloud.nix)
          {
            imports = [ "${nixpkgs}/nixos/modules/virtualisation/openstack-config.nix" ];
            _module.args.nixinate =  {
              host = "remote.worker";
              sshUser = "John88";
              substituteOnTarget = true;
              hermetic = true;
              buildOn = "remote";
            };
          }
        ];
     };

      LINDA = nixpkgs.lib.nixosSystem
      {
        system = "x86_64-linux";
        modules =
        [
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
          {
            environment.systemPackages =
            [ 
              agenix.defaultPackage.x86_64-linux
              parsecgaming.packages.x86_64-linux.parsecgaming
            ];
          }
        ];
      };
    };
  };
}
