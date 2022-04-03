{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.cudatoolkit
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
