{ config, lib, pkgs, ... }:
{
  imports = [ ./i3wm_darthpjb.nix ];

  secrix.system.secrets = {
    xai_token.encrypted.file = ../../secrets/api_balances/xai_token;
    opencode_zen_token.encrypted.file = ../../secrets/api_balances/opencode_zen_token;
    opencode_go_token.encrypted.file = ../../secrets/api_balances/opencode_go_token;
  };

  systemd.tmpfiles.rules = [
    ''f ${config.secrix.system.secrets.xai_token.decrypted.path} -u John88 -g users -m 0644''
    ''f ${config.secrix.system.secrets.opencode_zen_token.decrypted.path} -u John88 -g users -m 0644''
    ''f ${config.secrix.system.secrets.opencode_go_token.decrypted.path} -u John88 -g users -m 0644''
  ];

  environment.systemPackages =
    let
      secretPaths = {
        xai = config.secrix.system.secrets.xai_token.decrypted.path;
        zen = config.secrix.system.secrets.opencode_zen_token.decrypted.path;
        go = config.secrix.system.secrets.opencode_go_token.decrypted.path;
      };

      apiScript = pkgs.writeShellApplication {
        name = \"api-balances\";
      runtimeInputs = [ pkgs.curl pkgs.jq ];
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        json=()

        # XAI (placeholder; no public API - use console.x.ai billing manually)
        if [[ -r ${lib.escapeShellArg secretPaths.xai} ]]; then
          XAI_TOKEN=''${XAI_TOKEN:=$(cat ${lib.escapeShellArg secretPaths.xai})}
          xai_balance=$(curl -s -f -H \"Authorization: Bearer \$XAI_TOKEN\" -H \"Content-Type: application/json\" https://console-api.x.ai/v1/billing/balance || echo '{\"balance\": \"N/A\"}')
          balance=\$(echo \$xai_balance | jq -r '.balance // \"N/A\"')
          color=\"#00ff00\"
          [[ \"\$balance\" =~ ^[0-9]+(\.[0-9]+)?\$ ]] && [[ \$(echo \"\$balance < 10\" | bc -l) = 1 ]] && color=\"#ff0000\" || [[ \$(echo \"\$balance < 50\" | bc -l) = 1 ]] && color=\"#ffaa00\"
          json+=(\"{\\\"full_text\\\":\\\"XAI: \\\$balance\\\",\\\"color\\\":\\\"\$color\\\"}\")
        else
          json+=(\"{\\\"full_text\\\":\\\"XAI: secret missing\\\",\\\"color\\\":\\\"#ff0000\\\"}\")
        fi

        # Opencode Zen (placeholder endpoint)
        if [[ -r ${lib.escapeShellArg secretPaths.zen} ]]; then
          ZEN_TOKEN=''${ZEN_TOKEN:=$(cat ${lib.escapeShellArg secretPaths.zen})}
          zen_balance=$(curl -s -f -H \"Authorization: Bearer \$ZEN_TOKEN\" https://api.opencode.zen/v1/account/balance || echo '{\"balance\": \"N/A\"}')
          balance=\$(echo \$zen_balance | jq -r '.balance // \"N/A\"')
          color=\"#00ff00\"
          [[ \"\$balance\" =~ ^[0-9]+(\.[0-9]+)?\$ ]] && [[ \$(echo \"\$balance < 10\" | bc -l) = 1 ]] && color=\"#ff0000\" || [[ \$(echo \"\$balance < 50\" | bc -l) = 1 ]] && color=\"#ffaa00\"
          json+=(\"{\\\"full_text\\\":\\\"Zen: \\\$balance\\\",\\\"color\\\":\\\"\$color\\\",\\\"separator\\\":false}\")
        else
          json+=(\"{\\\"full_text\\\":\\\"Zen: secret missing\\\",\\\"color\\\":\\\"#ff0000\\\",\\\"separator\\\":false}\")
        fi

        # Opencode Go (placeholder)
        if [[ -r ${lib.escapeShellArg secretPaths.go} ]]; then
          GO_TOKEN=''${GO_TOKEN:=$(cat ${lib.escapeShellArg secretPaths.go})}
          go_balance=$(curl -s -f -H \"Authorization: Bearer \$GO_TOKEN\" https://api.opencode.go/v1/account/balance || echo '{\"balance\": \"N/A\"}')
          balance=\$(echo \$go_balance | jq -r '.balance // \"N/A\"')
          color=\"#00ff00\"
          [[ \"\$balance\" =~ ^[0-9]+(\.[0-9]+)?\$ ]] && [[ \$(echo \"\$balance < 10\" | bc -l) = 1 ]] && color=\"#ff0000\" || [[ \$(echo \"\$balance < 50\" | bc -l) = 1 ]] && color=\"#ffaa00\"
          json+=(\"{\\\"full_text\\\":\\\"Go: \\\$balance\\\",\\\"color\\\":\\\"\$color\\\",\\\"separator\\\":false}\")
        else
          json+=(\"{\\\"full_text\\\":\\\"Go: secret missing\\\",\\\"color\\\":\\\"#ff0000\\\"}\")
        fi

        printf '%%s\\n' \"\''${json[*]}\"
      '';
    };
  in [ apiScript pkgs.i3blocks pkgs.bc ];

  # Port i3status to i3blocks config (/etc/i3blocks/config)
  environment.etc.\"i3blocks/config\".text = ''
    # Migrated from i3status; i3blocks INI format
    ; General
    [global]
    interval = 5

    ; Load (CPU)
    [load]
    format = CPU: %1min
    ; threshold for degraded = i3status threshold_degraded ~5G but for load

    ; Memory
    [memory]
    format = RAM: %used | %available
    threshold_degraded = 5G
    format_degraded = MEMORY < %available

    ; Ethernet br0
    [network]
    interface = br0
    format-up = E: %ip (%speed)
    format-down = E: down

    ; Disks
    [disk /home]
    format = HOME: %free

    [disk /speed-storage]
    format = SPEED: %free

    [disk /bulk-storage]
    format = BULK: %free

    ; Time
    [time]
    format = %Y-%m-%d %H:%M:%S
    timezone = local

    ; Custom API Balances
    [api_balances]
    command = ${lib.getExe pkgs.api-balances}  # From systemPackages
    interval = 30
  '';

  # Override i3status → i3blocks; copy base i3 config logic
  services.xserver.windowManager.i3 = lib.mkIf config.services.xserver.windowManager.i3.enable {
    configFile = let
      baseConfig = builtins.readFile (builtins.toString ./i3wm.nix + \"i3.config\");  # Pseudo; actual override
    in pkgs.writeText \"i3-balances.config\" ''
      # Full i3 config from i3wm.nix but replace line 222: status_command i3blocks
      ${lib.strings.replaceStrings [ \"   status_command i3status\" ] [ \"status_command i3blocks\" ] (builtins.readFile ./i3wm.nix)}
    '';
    extraPackages = lib.mkForce [ pkgs.i3blocks pkgs.betterlockscreen pkgs.rofi pkgs.i3lock ];
  };
}


