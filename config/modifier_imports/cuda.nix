{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.cudaPackages_11_4.cudatoolkit
    pkgs.cudaPackages_11_4.cudnn
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
