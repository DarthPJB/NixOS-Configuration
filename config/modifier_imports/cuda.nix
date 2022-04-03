{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.cudatoolkit_11
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
