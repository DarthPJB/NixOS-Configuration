# Fleet-wide LLM chat UI on alpha-three.
# Browser → nginx (WG :443, ACME wildcard) → open-webui :8081
# open-webui → LiteLLM gateway :8080 (OpenAI-compatible /v1)
#
# The API key is injected via secrix environment file — never in the Nix store.
#
# alpha-three sets `nixpkgs.config.cudaSupport = true` globally (via
# modifier_imports/cuda.nix) for its nvidia-gpu exporter and nvtop. That global
# flag would cascade into open-webui → sentence-transformers → pytorch, forcing
# a CUDA pytorch build from source. We don't need RAG/embedding features, so we
# scope open-webui to a CPU-only python package set via `overrideScope` instead
# of importing a duplicate nixpkgs instance (the old pkgsNoCuda workaround).
{ config, lib, pkgs, ... }:
let
  # Force pytorch to CPU-only for open-webui's dependency closure. open-webui
  # stays in the main nixpkgs instance — no duplicate import — and stable
  # nixpkgs has cached CPU binaries, so no pytorch source build is required.
  # (onnxruntime ships as a prebuilt wheel, so it is not affected by cudaSupport.)
  pythonNoCuda = pkgs.python3Packages.overrideScope (final: prev: {
    torch = prev.torch.override { cudaSupport = false; };
  });
in
{
  services.open-webui = {
    enable = true;
    port = 8081;
    host = "127.0.0.1";
    package = pkgs.open-webui.override { python3Packages = pythonNoCuda; };
    environment = {
      # Internal URL — open-webui is on the same machine as LiteLLM.
      # Using the external URL would round-trip through nginx TLS unnecessarily.
      OPENAI_API_BASE_URL = "http://127.0.0.1:8080";
    };
    # Environment file must contain OPENAI_API_KEY for LiteLLM authentication.
    # Encrypted from secrets/litellm-openai-env via secrix.
    environmentFile = config.secrix.system.secrets.open-webui-env.decrypted.path;
  };
}
