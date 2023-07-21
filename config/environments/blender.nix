{ config, pkgs, inputs, ... }:
{
  environment.systemPackages =
    let
      system = "x86_64-linux";
      pkgs_unstable = import inputs.nixpkgs_unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    [
      (pkgs_unstable.blender.override { cudaSupport = true; })
    ];
}
