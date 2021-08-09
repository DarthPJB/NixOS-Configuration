{
  description = "A NixOS flake for the Astralship and the machines aboard it.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      terminalzero = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./configuration.nix)
        ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}
