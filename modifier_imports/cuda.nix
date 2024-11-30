{ config, pkgs, inputs, self, ... }:
{

  nix.settings.trusted-public-keys = [
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  ];
  nix.settings.substituters = [
    "https://cuda-maintainers.cachix.org"
  ];

  environment.systemPackages =
    let
      pkgs_un = self.un_pkgs;
    in
    [
      pkgs.nvtopPackages.full
      pkgs.cudaPackages.cudatoolkit
      pkgs.cudaPackages.cudnn
#     pkgs.cudaPackages.cutensor
      #      pkgs.ollama
      #      (pkgs.llama-cpp.override { cudaSupport = true; })

      (pkgs.colmap.override { cudaSupport = true; })
      (pkgs.blender.override { cudaSupport = true; })
    ];

  nixpkgs.config = {
#    cudaSupport = true;
#    cudnnSupport = true;
    permittedInsecurePackages = [
      "freeimage"
      "freeimage-unstable-2021-11-01"
    ];
  };

}
