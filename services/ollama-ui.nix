# Fleet-wide LLM chat UI on alpha-three.
# Browser → nginx (WG :443, ACME wildcard) → open-webui :8081
# open-webui → LiteLLM gateway :8080 (OpenAI-compatible /v1)
#
# The API key is injected via secrix environment file — never in the Nix store.
{ config, lib, ... }:
{
  services.open-webui = {
    enable = true;
    port = 8081;
    host = "127.0.0.1";
    environment = {
      OPENAI_API_BASE_URL = "https://agentic-gateway.johnbargman.net";
    };
    environmentFile = config.secrix.system.secrets.open-webui-env.decrypted.path;
  };
}
