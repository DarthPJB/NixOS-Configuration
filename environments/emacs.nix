{ pkgs, inputs, ... }:

{
  environment.systemPackages =
    [
      inputs.nixpkgs_stable.legacyPackages.x86_64-linux.emacs
    ];
}
