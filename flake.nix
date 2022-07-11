{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    inputs.agenix.url = "github:ryantm/agenix";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = { self, nixpkgs, nixos-hardware,blender-bin, ... }@inputs:
  {
    nixosConfigurations =
    {
      Terminal-zero = nixpkgs.lib.nixosSystem
      {
        system = "x86_64-linux";
        modules =
        [
          (import ./config/configuration.nix)
          (import ./config/environments/i3wm_darthpjb.nix)
          (import ./config/environments/rtl-sdr.nix)
#          (import ./config/environments/bluetooth.nix)
          (import ./config/machines/terminalzero.nix)
           nixos-hardware.nixosModules.lenovo-thinkpad-x220
        ];
        specialArgs =
        {
          inherit inputs;
        };
      };
      Terminal-VM1 = nixpkgs.lib.nixosSystem
      {
        system = "x86_64-linux";
        modules =
        [
          (import ./config/configuration.nix)
          (import ./config/environments/i3wm_darthpjb.nix)
          (import ./config/machines/VirtualBox.nix)
        ];
        specialArgs =
        {
          inherit inputs;
        };
      };
      LINDA = nixpkgs.lib.nixosSystem
      {
        system = "x86_64-linux";
        modules =
        [
          (import ./config/configuration.nix)
          (import ./config/machines/LINDA.nix)
          (import ./config/environments/i3wm_darthpjb.nix)
          (import ./config/environments/bluetooth.nix)
          (import ./config/environments/steam.nix)
          (import ./config/environments/code.nix)
          (import ./config/environments/neovim.nix)
          (import ./config/environments/cad_and_graphics.nix)
          (import ./config/environments/audio_visual_editing.nix)
          (import ./config/environments/general_fonts.nix)
          (import ./config/environments/video_call_streaming.nix)
          (import ./config/locale/tailscale.nix)
          (import ./config/modifier_imports/memtest.nix)
          (import ./config/modifier_imports/cuda.nix)
          (import ./config/modifier_imports/ipfs.nix)
          (import ./config/modifier_imports/hosts.nix)
	  (import ./config/modifier_imports/virtualisation-virtualbox.nix)
          agenix.nixosModule
        ];
        specialArgs =
        {
          inherit inputs;
        };
      };
    };
  };
}
