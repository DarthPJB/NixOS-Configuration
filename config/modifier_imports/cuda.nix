{ config, pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.cudatoolkit_10
    pkgs.cudatoolkit_11_6
  ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
