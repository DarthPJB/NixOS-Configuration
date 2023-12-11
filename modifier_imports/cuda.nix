{ config, pkgs, inputs, ... }:
{
  environment.systemPackages =
    let
      pkgs = import inputs.nixpkgs_stable { system = "x86_64-linux"; config.allowUnfree = true; };
    in
    [
      pkgs.nvtop
      pkgs.cudaPackages.cudatoolkit
      pkgs.cudaPackages.cudnn
      pkgs.cudaPackages.cutensor
      (pkgs.colmap.override { cudaSupport = true; })
      (pkgs.blender.override { cudaSupport = true; })
    ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
