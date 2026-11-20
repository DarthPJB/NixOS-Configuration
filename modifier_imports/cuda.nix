{ config
, pkgs
, lib
, unstable
, self
, ...
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
    # colmap vs CUDA-poisoned cholmod.h. The dependency graph smuggles the
    # global CUDA suitesparse's dev output into the include race (its
    # cholmod.h hard-codes `#define CHOLMOD_HAS_CUDA`, dragging cublas_v2.h →
    # cuda_fp16.h → C++ <utility> into Eigen 3.4.1's `extern "C"` cholmod
    # wrapper — "template with C linkage", in colmap and caspar alike).
    # The shield is cholmod.h's own documented escape: NLARGEFILE skips the
    # MATLAB block (io64.h), MATHWORKS undefs CHOLMOD_HAS_CUDA regardless of
    # which cholmod.h wins the include race; struct fields fall to void* —
    # ABI-identical. No-op on CPU-only headers, and surface-agnostic (the
    # stable/unstable callPackage signatures differ — overrideAttrs only).
    # Live upstream too. Retire when nixpkgs/eigen/suitesparse absorb fixes.
    ((pkgs.colmap.override { cudaSupport = true; }).overrideAttrs
      (old: {
        NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -DNLARGEFILE -DMATHWORKS";
      }))
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
