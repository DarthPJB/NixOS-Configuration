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
      #      pkgs.ollama
      #      (pkgs.llama-cpp.override { cudaSupport = true; })
      (pkgs.colmap.override { cudaSupport = true; })
      (pkgs_un.blender.override { cudaSupport = true; })
    ];

  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
    cudnnSupport = true;
  };
}
