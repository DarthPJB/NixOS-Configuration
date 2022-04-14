{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.cudaPackages_11_6.cudatoolkit
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
