{
  description = "A NixOS flake for the Astralship and the machines aboard it.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
#    croughanator.url = "github:MatthewCroughan/nixcfg";
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
          (import ./config/machines/terminalzero.nix)
           nixos-hardware.nixosModules.lenovo-thinkpad-x250
        ];
        specialArgs =
        {
          inherit inputs;
        };
      };
    };
  };
}
