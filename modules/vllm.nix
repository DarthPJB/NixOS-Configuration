# modules/vllm.nix
# NixOS module for vLLM inference server
# Provides OpenAI-compatible API for LLM serving with GPU acceleration
#
# Usage (single model):
#   services.vllm.enable = true;
#   services.vllm.model = "Qwen/Qwen3-14B";
#
# Usage (multiple models):
#   services.vllm.enable = true;
#   services.vllm.models = [
#     { name = "qwen3-14b"; model = "Qwen/Qwen3-14B"; port = 8001; }
#     { name = "qwen3-8b"; model = "Qwen/Qwen3-8B"; port = 8002; }
#   ];
#
# LINDA has RTX 3060 (12GB) + GTX 1050 (2GB)
# Only the 3060 is useful for inference; 1050 is too small.
# Max VRAM capacity: ~11.2GB usable after driver overhead.
# Sweet spot: 8-14B dense models at Q4_K_M quantization.
{ config
, lib
, pkgs
, pkgs_llm ? null
, pkgsCuda ? null
, pkgsCpuVllm ? null
, ...
}:

let
  cfg = config.services.vllm;

  # Two nixpkgs_llm imports in flake.nix — not an overlay:
  #   pkgsCuda  — cudaSupport = true, GPU vLLM
  #   pkgs_llm  — CPU-only, wrapped as pkgsCpuVllm (+cpu metadata + zentorch)
  defaultGpuPackage =
    if pkgsCuda != null && pkgsCuda ? vllm then pkgsCuda.vllm else pkgs.vllm;
  defaultCpuPackage =
    if pkgsCpuVllm != null then pkgsCpuVllm
    else if pkgs_llm != null && pkgs_llm ? vllm then pkgs_llm.vllm
    else pkgs.vllm;

  packageFor = modelCfg:
    if modelCfg.device == "cpu" then cfg.cpuPackage else cfg.gpuPackage;

  # Build the vllm serve command arguments for a model config
  buildVllmArgs = modelCfg: lib.concatStringsSep " " (
    # modelPath (nix store) takes precedence over the HuggingFace model ID
    [ "--model" (if modelCfg.modelPath != null then "${modelCfg.modelPath}" else modelCfg.model) ]
    ++ [ "--host" modelCfg.host "--port" (toString modelCfg.port) ]
    # CPU: do NOT pass --device cpu. CpuPlatform is selected via +cpu metadata;
    # passing --device cpu triggers device_control_id_to_physical_device_id
    # which tries int("cpu") and fails. GPU flags are GPU-only.
    ++ lib.optionals (modelCfg.device == "gpu") [
      "--tensor-parallel-size"
      (toString modelCfg.tensorParallelSize)
      "--gpu-memory-utilization"
      (toString modelCfg.gpuMemoryUtilization)
    ]
    ++ lib.optionals (modelCfg.servedModelName != null) [
      "--served-model-name"
      modelCfg.servedModelName
    ]
    ++ lib.optionals (modelCfg.maxModelLen != null) [
      "--max-model-len"
      modelCfg.maxModelLen
    ]
    ++ lib.optionals (modelCfg.dtype != null) [
      "--dtype"
      modelCfg.dtype
    ]
    ++ lib.optionals (modelCfg.quantization != null) [
      "--quantization"
      modelCfg.quantization
    ]
    ++ lib.optionals (modelCfg.device == "gpu" && modelCfg.attentionBackend != null) [
      "--attention-backend"
      modelCfg.attentionBackend
    ]
    ++ lib.optionals modelCfg.enforceEager [ "--enforce-eager" ]
    ++ lib.optionals modelCfg.disableLogStats [ "--disable-log-stats" ]
    ++ modelCfg.extraArgs
  );

  # Default model options
  defaultModelOptions = {
    host = cfg.host;
    tensorParallelSize = cfg.tensorParallelSize;
    gpuMemoryUtilization = cfg.gpuMemoryUtilization;
    dtype = cfg.dtype;
    attentionBackend = cfg.attentionBackend;
    enforceEager = cfg.enforceEager;
    disableLogStats = cfg.disableLogStats;
    # Hardware assignment and model source (Phase 2: vLLM-only migration)
    device = cfg.device;
    modelPath = cfg.modelPath;
    cpuKvCacheSpace = cfg.cpuKvCacheSpace;
    cpuOmpThreadsBind = cfg.cpuOmpThreadsBind;
  };

  # Build model list: either from models list or single model
  modelList =
    if cfg.models != [ ]
    then map (m: defaultModelOptions // m) cfg.models
    else [
      (defaultModelOptions // {
        name = "default";
        model = cfg.model;
        servedModelName = null;
        port = cfg.port;
        maxModelLen = cfg.maxModelLen;
        quantization = cfg.quantization;
        extraArgs = cfg.extraArgs;
      })
    ];

  # Environment variables, computed per model config.
  # TORCHINDUCTOR_CACHE_DIR: persist torch.compile cubin cache across service
  # restarts. Without this, PrivateTmp or /tmp cleanup destroys compiled kernels.
  # CPU models: blank CUDA_VISIBLE_DEVICES (no GPU access) and configure the
  # CPU KV cache space / OpenMP thread binding via vLLM environment variables.
  # modelPath: models already live in the nix store, so pin HF_HOME to the cache
  # dir instead of a runtime download location.
  # VLLM_USE_FLASHINFER_SAMPLER=0: disable FlashInfer JIT for sampling, use
  # pre-compiled triton fallback instead. Avoids need for gcc/ninja/nvcc at
  # runtime and allows security hardening to remain enabled.
  envVarsFor = modelCfg:
    {
      CUDA_VISIBLE_DEVICES =
        if modelCfg.device == "cpu" then "" else cfg.cudaVisibleDevices;
      TORCHINDUCTOR_CACHE_DIR = "${cfg.cacheDir}/torch_compile";
    }
    // lib.optionalAttrs (modelCfg.device == "gpu") {
      VLLM_USE_FLASHINFER_SAMPLER = "0";
    }
    // lib.optionalAttrs (modelCfg.device == "cpu") {
      VLLM_CPU_KVCACHE_SPACE = toString modelCfg.cpuKvCacheSpace;
      VLLM_CPU_OMP_THREADS_BIND = modelCfg.cpuOmpThreadsBind;
    }
    // lib.optionalAttrs (modelCfg.modelPath != null) {
      HF_HOME = "${cfg.cacheDir}/huggingface";
    }
    // cfg.environmentVariables;

in
{
  options.services.vllm = {
    enable = lib.mkEnableOption "vLLM inference server";

    package = lib.mkOption {
      type = lib.types.package;
      default = cfg.gpuPackage;
      defaultText = "config.services.vllm.gpuPackage";
      description = "Default vLLM package (GPU). Prefer gpuPackage / cpuPackage.";
    };

    gpuPackage = lib.mkOption {
      type = lib.types.package;
      default = defaultGpuPackage;
      defaultText = "pkgsCuda.vllm";
      description = "vLLM package for GPU models (CUDA build)";
    };

    cpuPackage = lib.mkOption {
      type = lib.types.package;
      default = defaultCpuPackage;
      defaultText = "pkgsCpuVllm";
      description = "vLLM package for CPU models (+cpu metadata, zentorch)";
    };

    # Single model config (backward compatible)
    model = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "Qwen/Qwen3-14B";
      description = ''
        Model name or path (single-model mode).
        Can be a HuggingFace model ID or local path.
        Ignored if services.vllm.models is set.
      '';
    };

    # Multi-model config
    models = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Unique name for this model (used in systemd service name)";
          };
          model = lib.mkOption {
            type = lib.types.str;
            description = "HuggingFace model ID or local path";
          };
          servedModelName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Alias for the model in the API (e.g., 'qwen3' instead of 'Qwen/Qwen3-14B')";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 8000;
            description = "Port for this model's API server";
          };
          device = lib.mkOption {
            type = lib.types.enum [
              "gpu"
              "cpu"
            ];
            default = cfg.device;
            description = ''
              Device to run inference on: "gpu" (CUDA/NVIDIA) or "cpu" (CPU-only).
              CPU models get no GPU access and use vLLM's CPU backend.
              Defaults to the global services.vllm.device.
            '';
          };
          cpuKvCacheSpace = lib.mkOption {
            type = lib.types.int;
            default = cfg.cpuKvCacheSpace;
            description = ''
              CPU KV cache size in GiB (used when device == "cpu").
              Defaults to the global services.vllm.cpuKvCacheSpace.
            '';
          };
          cpuOmpThreadsBind = lib.mkOption {
            type = lib.types.str;
            default = cfg.cpuOmpThreadsBind;
            description = ''
              CPU core binding for OpenMP threads (used when device == "cpu").
              Defaults to the global services.vllm.cpuOmpThreadsBind.
            '';
          };
          modelPath = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = cfg.modelPath;
            description = ''
              Path to a model in the nix store. When set, vLLM loads the model
              from this path instead of downloading it from HuggingFace. Accepts
              a store path, an absolute path, or a derivation (e.g. self.models.qwen3-8b).
              Defaults to the global services.vllm.modelPath.
            '';
          };
          maxModelLen = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Maximum context length for this model";
          };
          dtype = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum [
              "auto"
              "bfloat16"
              "float16"
              "float32"
            ]);
            default = cfg.dtype;
            description = ''
              Data type for model weights and activations.
              "auto" uses FP16 for FP32/FP16 models, BF16 for BF16 models.
              CPU models: "bfloat16" halves RAM vs float32 on AMD Zen.
              Defaults to the global services.vllm.dtype.
            '';
          };
          quantization = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Quantization method (awq, gptq, fp8, etc.)";
          };
          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additional CLI arguments for this model";
          };
          autoStart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether this model service starts at boot (wantedBy = multi-user.target).
              Set to false for services that should only be started manually:
                systemctl start vllm-<name>
            '';
          };
          enforceEager = lib.mkOption {
            type = lib.types.bool;
            default = cfg.enforceEager;
            description = ''
              Skip torch.compile, use eager mode. Recommended for CPU models
              where compilation hangs on large models. Defaults to the global
              services.vllm.enforceEager.
            '';
          };
        };
      });
      default = [ ];
      description = ''
        List of models to serve. Each model gets its own systemd service.
        When set, the single-model options (model, port, etc.) are ignored.
        Note: With 12GB VRAM, only one model can be loaded at a time.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host to bind the API server(s)";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Default port for the API server (single-model mode)";
    };

    tensorParallelSize = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = ''
        Number of tensor parallel groups.
        Set to 2 for multi-GPU model parallelism across 2 GPUs.
        For LINDA: 1 is optimal (RTX 3060 alone handles most 7B-14B quantized models).
      '';
    };

    gpuMemoryUtilization = lib.mkOption {
      type = lib.types.float;
      default = 0.9;
      description = "GPU memory utilization fraction (0.0-1.0)";
    };

    maxModelLen = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "16384";
      description = ''
        Maximum model context length (single-model mode).
        null = auto-detect from model config.
      '';
    };

    dtype = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "auto"
        "bfloat16"
        "float16"
        "float32"
      ]);
      default = "auto";
      description = ''
        Data type for model weights and activations.
        "auto" uses FP16 for FP32/FP16 models, BF16 for BF16 models.
      '';
    };

    quantization = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "awq";
      description = ''
        Quantization method (single-model mode). null = no quantization.
        Common values: "awq", "gptq", "squeezellm", "fp8".
      '';
    };

    attentionBackend = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "FLASH_ATTN"
        "FLASHINFER"
        "TORCH_SDPA"
      ]);
      default = "FLASH_ATTN";
      description = ''
        Attention backend. FLASH_ATTN uses pre-compiled kernels (no JIT).
        FLASHINFER requires runtime JIT compilation (gcc, ninja, nvcc).
      '';
    };

    enforceEager = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable CUDA graphs, always use eager mode (slower but more compatible)";
    };

    disableLogStats = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable periodic statistics logging";
    };

    cudaVisibleDevices = lib.mkOption {
      type = lib.types.str;
      default = "0";
      example = "0,1";
      description = ''
        CUDA_VISIBLE_DEVICES value (comma-separated GPU indices).
        LINDA: "0" for RTX 3060 only, "0,1" for both GPUs.
        Note: GTX 1050 (2GB) is too small for most models.
      '';
    };

    device = lib.mkOption {
      type = lib.types.enum [
        "gpu"
        "cpu"
      ];
      default = "gpu";
      description = ''
        Device to run inference on: "gpu" (CUDA/NVIDIA) or "cpu" (CPU-only).
        CPU models get no GPU access and use vLLM's CPU backend.
      '';
    };

    modelPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/nix/store/...-qwen3-8b";
      description = ''
        Path to a model in the nix store. When set, vLLM loads the model from
        this path instead of downloading it from HuggingFace. Accepts a store
        path, an absolute path, or a derivation (e.g. pkgs.models.qwen3-8b).
      '';
    };

    cpuKvCacheSpace = lib.mkOption {
      type = lib.types.int;
      default = 4;
      example = 40;
      description = "CPU KV cache size in GiB (used when device == \"cpu\")";
    };

    cpuOmpThreadsBind = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      example = "0-29";
      description = ''
        CPU core binding for OpenMP threads (used when device == "cpu").
        "auto" lets vLLM decide; a range like "0-29" pins threads to cores.
      '';
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        VLLM_WORKER_MULTIPROC_METHOD = "fork";
      };
      description = "Additional environment variables for the vLLM service(s)";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--enable-prefix-caching" "--max-num-seqs" "64" ];
      description = "Additional CLI arguments (single-model mode)";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port(s) for the API server(s)";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/cache/vllm";
      description = "Directory for model cache and downloads";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tensorParallelSize >= 1;
        message = "services.vllm.tensorParallelSize must be >= 1";
      }
      {
        assertion = cfg.gpuMemoryUtilization > 0.0 && cfg.gpuMemoryUtilization <= 1.0;
        message = "services.vllm.gpuMemoryUtilization must be between 0.0 and 1.0";
      }
      {
        assertion = cfg.cpuKvCacheSpace >= 1;
        message = "services.vllm.cpuKvCacheSpace must be >= 1 (GiB)";
      }
      {
        assertion = cfg.model != "" || cfg.models != [ ] || cfg.modelPath != null;
        message = "services.vllm: either 'model', 'models', or 'modelPath' must be set";
      }
    ];

    # CUDA is scoped to a separate nixpkgs_llm import (pkgsCuda in flake.nix) —
    # NOT set globally here. A global nixpkgs.config.cudaSupport would cascade
    # CUDA into every package on the machine (torch, ollama, blender, etc.).

    # Add vLLM and runtime dependencies to system packages
    # util-linux provides lscpu (CPU worker needs it for topology detection)
    environment.systemPackages = [ cfg.gpuPackage pkgs.which pkgs.util-linux ]
      ++ lib.optional (lib.any (m: m.device == "cpu") modelList) cfg.cpuPackage;

    # Dedicated system user — no login, no home shell, group for cache access
    users.groups.vllm = { };
    users.users.vllm = {
      isSystemUser = true;
      group = "vllm";
      home = "/var/lib/vllm";
      createHome = true;
      description = "vLLM inference server service account";
      extraGroups = [ "video" "render" ];
    };

    # Generate systemd service for each model
    systemd.services = lib.listToAttrs (map
      (modelCfg: {
        name = "vllm-${modelCfg.name}";
        value = {
          description = "vLLM Inference Server — ${modelCfg.name}";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = lib.mkIf modelCfg.autoStart [ "multi-user.target" ];
          startLimitBurst = 3;
          startLimitIntervalSec = 300;

          environment = lib.mapAttrs (_: toString) (envVarsFor modelCfg);

          serviceConfig = {
            ExecStart = "${lib.getExe' (packageFor modelCfg) "vllm"} serve ${buildVllmArgs modelCfg}";
            User = "vllm";
            Group = "vllm";
            Restart = "on-failure";
            RestartSec = 15;
            TimeoutStartSec = 300; # Model loading can take time
            TimeoutStopSec = 30;

            # CPU models: cap memory to protect the host (weights + KV cache
            # live in RAM instead of VRAM).
            MemoryMax = lib.mkIf (modelCfg.device == "cpu") "80%";

            # Security hardening
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ cfg.cacheDir "/tmp" "/var/lib/vllm" ];
            # PrivateTmp disabled: torch.compile (TritonBundler) writes cubin
            # cache to /tmp/torchinductor_root/. PrivateTmp wipes this on each
            # restart, causing "Cubin file not found" crashes. LINDA's /tmp is
            # a ZFS dataset (speed-storage/tmp) so persistence is safe.
            PrivateTmp = false;

            # Resource limits
            LimitNOFILE = 65536;
          };
        };
      })
      modelList);

    # Firewall - open all model ports
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = map (m: m.port) modelList;
    };

    # Cache directories — owned by vllm service user
    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 vllm vllm -"
      "d ${cfg.cacheDir}/torch_compile 0755 vllm vllm -"
      "d ${cfg.cacheDir}/huggingface 0755 vllm vllm -"
    ];
  };
}
