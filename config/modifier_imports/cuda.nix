{ config, pkgs, ... }:
{
  environment.systemPackages = [
  cudatoolkit
  ];
  nixpkgs.config = {
    cudaSupport = true;
  };
}
