{
  config,
  pkgs,
  unstable,
  self,
  ...
}:
{
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [
    config.services.prometheus.exporters.nvidia-gpu.port
  ];
  services.prometheus = {
    exporters.nvidia-gpu = {
      enable = true;
      port = 3103;
    };
  };
  environment.systemPackages = [
    pkgs.nvtopPackages.full
    pkgs.cudaPackages.cudatoolkit
    #pkgs.cudaPackages.cudnn
    # pkgs.cudaPackages.cutensor
    unstable.ollama-cuda
    (unstable.llama-cpp.override { cudaSupport = true; })
    (pkgs.colmap.override { cudaSupport = true; })
    (pkgs.blender.override { cudaSupport = true; })
  ];

  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
    permittedInsecurePackages = [
      # "freeimage-3.18.0-unstable-2024-04-18"
    ];
  };

}
