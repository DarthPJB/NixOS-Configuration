# Fleet-wide Ollama chat UI on alpha-three.
# Browser → nginx (WG :443, ACME wildcard) → nextjs-ollama-llm-ui :8081
# UI server → 127.0.0.1:11434 facade → LiteLLM /ollama passthrough :8080
#
# The UI speaks Ollama native /api/* only. LiteLLM exposes that under /ollama/.
# The facade injects the gateway master key so the UI never sees a secret.
{ config, lib, pkgs, ... }:
let
  uiPort = 8081;
  facadePort = 11434;
  authSnippet = "/run/nginx/litellm-ui-auth.conf";
  keyFile = config.secrix.system.secrets.litellm-master.decrypted.path;

  writeAuthSnippet = pkgs.writeShellApplication {
    name = "write-litellm-ui-auth";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${lib.getExe' pkgs.coreutils "mkdir"} -p /run/nginx
      key=$(${lib.getExe' pkgs.coreutils "tr"} -d '\n' < "${keyFile}")
      ${lib.getExe' pkgs.coreutils "printf"} 'proxy_set_header Authorization "Bearer %s";\n' "$key" > ${authSnippet}
      ${lib.getExe' pkgs.coreutils "chmod"} 0640 ${authSnippet}
      ${lib.getExe' pkgs.coreutils "chown"} nginx:nginx ${authSnippet}
    '';
  };
in
{
  services.nextjs-ollama-llm-ui = {
    enable = true;
    port = uiPort;
    # Facade looks like native Ollama so the UI keeps calling /api/tags, /api/chat.
    ollamaUrl = "http://127.0.0.1:${toString facadePort}";
  };

  # Write the Authorization snippet before nginx starts (secrets already decrypted).
  systemd.services.nginx.preStart = lib.mkAfter (lib.getExe writeAuthSnippet);

  # Localhost-only facade — not a topology vhost.
  services.nginx.virtualHosts."litellm-ollama-facade" = {
    listen = [{
      addr = "127.0.0.1";
      port = facadePort;
    }];
    locations."/" = {
      extraConfig = ''
        include ${authSnippet};
        proxy_pass http://127.0.0.1:8080/ollama/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_read_timeout 1200s;
        proxy_send_timeout 1200s;
      '';
    };
  };
}
