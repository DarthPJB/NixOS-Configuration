{
  description = "A NixOS flake for John Bargman's machine provisioning";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    parsecgaming.url = "github:DarthPJB/parsec-gaming-nix";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs:
  {
    nixosConfigurations =
    {
      Terminal-zero = nixpkgs.lib.nixosSystem
      {
        system = "x86_64-linux";
        modules =
        [
          (import ./config/configuration.nix)
          (import ./enviroments/sway.nix)
          (import ./config/machines/terminalzero.nix)
           nixos-hardware.nixosModules.lenovo-thinkpad-x250
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
          (import ./enviroments/i3wm_darthpjb.nix)
          (import ./config/machines/VirtualBox.nix)
        ];
        specialArgs =
        {
          inherit inputs;
        };
      };
    };
  };
}
