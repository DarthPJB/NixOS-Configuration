{ pkgs, inputs, ... }:
let 
pkgs = inputs.nixpkgs_stable.legacyPackages.x86_64-linux;
in
{
  environment.systemPackages = with pkgs;
    [
      pkgs.emacs
      pkgs.nix-top
    ];
}
