{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.cudaPackages_10_2.cudatoolkit
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
