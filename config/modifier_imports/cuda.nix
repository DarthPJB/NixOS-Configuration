{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.nvtop
    pkgs.cudaPackages_11_6.cudatoolkit
    pkgs.cudaPackages_11_6.cudnn
    pkgs.cudaPackages_11_6.cutensor
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
