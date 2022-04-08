{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.cudatoolkit_10_2
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
