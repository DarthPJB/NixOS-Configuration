{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.cudaPackages_11_6.cudatoolkit
    pkgs.cudaPackages_11_6.cudnn
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
