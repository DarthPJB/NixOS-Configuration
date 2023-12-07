{ pkgs, inputs, ... }:

{
  environment.systemPackages =
    [
      inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.neovim
    ];
}
