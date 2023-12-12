{ config, pkgs, inputs, self, ... }:
{
  environment.systemPackages =
    let
      pkgs_un = self.un_pkgs;
    in
    [
      pkgs.nvtop
      pkgs.cudaPackages.cudatoolkit
      pkgs.cudaPackages.cudnn
      pkgs.cudaPackages.cutensor
      pkgs_un.ollama
      (pkgs.colmap.override { cudaSupport = true; })
      (pkgs_un.blender.override { cudaSupport = true; })
    ];
  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
  };
}
