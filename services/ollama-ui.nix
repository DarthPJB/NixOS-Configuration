# Fleet-wide LLM chat UI on alpha-three.
# Browser → nginx (WG :443, ACME wildcard) → open-webui :8081
# open-webui → LiteLLM gateway :8080 (OpenAI-compatible /v1)
#
# The API key is injected via secrix environment file — never in the Nix store.
#
# open-webui pulls in sentence-transformers → pytorch when cudaSupport is true.
# We don't need RAG/embedding features, so we override to cudaSupport = false.
# This avoids building pytorch from source — stable nixpkgs has cached CPU binaries.
{ config, lib, pkgs, ... }:
let
  # open-webui without CUDA — avoids pytorch+CUDA build from source.
  pkgsNoCuda = import pkgs.path { inherit (pkgs.stdenv.hostPlatform) system; config.allowUnfree = true; };
in
{
  services.open-webui = {
    enable = true;
    port = 8081;
    host = "127.0.0.1";
    package = pkgsNoCuda.open-webui;
    environment = {
      OPENAI_API_BASE_URL = "https://agentic-gateway.johnbargman.net";
    };
    environmentFile = config.secrix.system.secrets.open-webui-env.decrypted.path;
  };
}
