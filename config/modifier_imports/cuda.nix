{ config, pkgs, inputs, ... }:
{
  environment.systemPackages =
    let
      pkgs = import inputs.nixpkgs_stable { system = "x86_64-linux"; config.allowUnfree = true; };
    in
    [
      pkgs.nvtop
      pkgs.cudaPackages_11_6.cudatoolkit
      pkgs.cudaPackages_11_6.cudnn
      pkgs.cudaPackages_11_6.cutensor
      (pkgs.colmap.override { cudaSupport = true; })
      (pkgs.blender.override { cudaSupport = true; })
    ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
