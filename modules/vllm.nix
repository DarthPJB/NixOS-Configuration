# modules/vllm.nix
# NixOS module for vLLM inference server
# Provides OpenAI-compatible API for LLM serving with GPU acceleration
#
# Usage:
#   services.vllm.enable = true;
#   services.vllm.model = "Qwen/Qwen2.5-1.5B-Instruct";
#
# LINDA has RTX 3060 (12GB) + GTX 1050 (2GB)
# Only the 3060 is useful for inference; 1050 is too small.
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

  # Build the vllm serve command arguments
  vllmArgs = lib.concatStringsSep " " (
    [ "--model" cfg.model ]
    ++ [ "--host" cfg.host "--port" (toString cfg.port) ]
    ++ [ "--tensor-parallel-size" (toString cfg.tensorParallelSize) ]
    ++ [ "--gpu-memory-utilization" (toString cfg.gpuMemoryUtilization) ]
    ++ lib.optionals (cfg.maxModelLen != null) [
      "--max-model-len" cfg.maxModelLen
    ]
    ++ lib.optionals (cfg.dtype != null) [
      "--dtype" cfg.dtype
    ]
    ++ lib.optionals (cfg.quantization != null) [
      "--quantization" cfg.quantization
    ]
    ++ lib.optionals (cfg.attentionBackend != null) [
      "--attention-backend" cfg.attentionBackend
    ]
    ++ lib.optionals cfg.enforceEager [ "--enforce-eager" ]
    ++ lib.optionals cfg.disableLogStats [ "--disable-log-stats" ]
    ++ cfg.extraArgs
  );

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

    model = lib.mkOption {
      type = lib.types.str;
      example = "Qwen/Qwen2.5-1.5B-Instruct";
      description = ''
        Model name or path. Can be:
        - HuggingFace model ID (e.g., "Qwen/Qwen2.5-1.5B-Instruct")
        - Local path to model weights
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host to bind the API server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port for the API server";
    };

    tensorParallelSize = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = ''
        Number of tensor parallel groups.
        Set to 2 for multi-GPU model parallelism across 2 GPUs.
        For LINDA: 1 is optimal (RTX 3060 alone handles most 7B-27B quantized models).
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
        Maximum model context length (prompt + output tokens).
        null = auto-detect from model config.
        Use "-1" or "auto" to let vLLM find the largest fitting context length.
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
        Quantization method. null = no quantization.
        Common values: "awq", "gptq", "squeezellm", "fp8".
        For GGUF/ollama models, use the HF quantized variant instead.
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
      description = "Additional environment variables for the vLLM service";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--enable-prefix-caching" "--max-num-seqs" "64" ];
      description = "Additional CLI arguments passed to vllm serve";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for the API server";
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
    ];

    # Ensure CUDA support is enabled system-wide
    nixpkgs.config = {
      cudaSupport = true;
      cudnnSupport = true;
    };

    # Add vLLM to system packages
    environment.systemPackages = [ cfg.package ];

    # Systemd service
    systemd.services.vllm = {
      description = "vLLM Inference Server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      startLimitBurst = 3;
      startLimitIntervalSec = 300;

      environment = lib.mapAttrs (_: toString) envVars;

      serviceConfig = {
        ExecStart = "${lib.getExe' cfg.package "vllm"} serve ${vllmArgs}";
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

    # Firewall
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    # Cache directory
    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 root root -"
    ];
  };
}
