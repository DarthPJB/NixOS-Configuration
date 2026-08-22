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
, ...
}:

let
  cfg = config.services.vllm;

  # vLLM is in nixpkgs_llm (unstable), not stable nixpkgs
  # pkgs_llm is passed via _module.args from the flake
  vllmPackage = if pkgs_llm != null && pkgs_llm ? vllm
    then pkgs_llm.vllm
    else pkgs.vllm;

  # Build the vllm serve command arguments for a model config
  buildVllmArgs = modelCfg: lib.concatStringsSep " " (
    [ "--model" modelCfg.model ]
    ++ [ "--host" modelCfg.host "--port" (toString modelCfg.port) ]
    ++ [ "--tensor-parallel-size" (toString modelCfg.tensorParallelSize) ]
    ++ [ "--gpu-memory-utilization" (toString modelCfg.gpuMemoryUtilization) ]
    ++ lib.optionals (modelCfg.servedModelName != null) [
      "--served-model-name" modelCfg.servedModelName
    ]
    ++ lib.optionals (modelCfg.maxModelLen != null) [
      "--max-model-len" modelCfg.maxModelLen
    ]
    ++ lib.optionals (modelCfg.dtype != null) [
      "--dtype" modelCfg.dtype
    ]
    ++ lib.optionals (modelCfg.quantization != null) [
      "--quantization" modelCfg.quantization
    ]
    ++ lib.optionals (modelCfg.attentionBackend != null) [
      "--attention-backend" modelCfg.attentionBackend
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
  };

  # Build model list: either from models list or single model
  modelList = if cfg.models != []
    then map (m: defaultModelOptions // m) cfg.models
    else [ (defaultModelOptions // {
      name = "default";
      model = cfg.model;
      servedModelName = null;
      port = cfg.port;
      maxModelLen = cfg.maxModelLen;
      quantization = cfg.quantization;
      extraArgs = cfg.extraArgs;
    }) ];

  # Environment variables
  envVars = {
    CUDA_VISIBLE_DEVICES = cfg.cudaVisibleDevices;
  } // cfg.environmentVariables;

in
{
  options.services.vllm = {
    enable = lib.mkEnableOption "vLLM inference server";

    package = lib.mkOption {
      type = lib.types.package;
      default = vllmPackage;
      defaultText = "vllmPackage (from nixpkgs_llm)";
      description = "vLLM package to use";
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
          maxModelLen = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Maximum context length for this model";
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
      default = null;
      description = ''
        Attention backend. null = auto-select best for hardware.
        FLASH_ATTN recommended for NVIDIA GPUs.
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
        assertion = cfg.model != "" || cfg.models != [];
        message = "services.vllm: either 'model' or 'models' must be set";
      }
    ];

    # Ensure CUDA support is enabled system-wide
    nixpkgs.config = {
      cudaSupport = true;
      cudnnSupport = true;
    };

    # Add vLLM to system packages
    environment.systemPackages = [ cfg.package ];

    # Generate systemd service for each model
    systemd.services = lib.listToAttrs (map (modelCfg: {
      name = "vllm-${modelCfg.name}";
      value = {
        description = "vLLM Inference Server — ${modelCfg.name}";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        startLimitBurst = 3;
        startLimitIntervalSec = 300;

        environment = lib.mapAttrs (_: toString) envVars;

        serviceConfig = {
          ExecStart = "${lib.getExe' cfg.package "vllm"} serve ${buildVllmArgs modelCfg}";
          Restart = "on-failure";
          RestartSec = 15;
          TimeoutStartSec = 300; # Model loading can take time
          TimeoutStopSec = 30;

          # GPU access
          SupplementaryGroups = [ "video" "render" ];

          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = false; # Models may be in /home
          ReadWritePaths = [ cfg.cacheDir "/speed-storage" ];

          # Resource limits
          LimitNOFILE = 65536;
        };
      };
    }) modelList);

    # Firewall - open all model ports
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = map (m: m.port) modelList;
    };

    # Cache directory
    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 root root -"
    ];
  };
}
