{ config, pkgs, self, ... }:
{
networking.firewall.interfaces."wireg0".allowedTCPPorts = [ config.services.prometheus.exporters.nvidia-gpu.port ];
  services.prometheus = {
    exporters.nvidia-gpu = {
      enable = true;
      port = 3103;
    };
  };
  environment.systemPackages =
    let
      pkgs_un = self.un_pkgs;
    in
    [
      pkgs.nvtopPackages.full
      pkgs.cudaPackages.cudatoolkit
      pkgs.cudaPackages.cudnn
      pkgs.cudaPackages.cutensor
      #      pkgs.ollama
      (pkgs.llama-cpp.override { cudaSupport = true; })
      (pkgs.colmap.override { cudaSupport = true; })
      (pkgs.blender.override { cudaSupport = true; })
    ];

  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
    permittedInsecurePackages = [
      "freeimage-3.18.0-unstable-2024-04-18"
    ];
  };

}
