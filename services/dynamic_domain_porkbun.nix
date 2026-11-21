{ config
, lib
, pkgs
, self
, ...
}:
let
  domain = "johnbargman.net";
  subdomain = config.networking.hostName;

  keyPath =
    config.secrix.services."dynamic-${domain}".secrets.porkbun_api_key.decrypted.path;
  secretPath =
    config.secrix.services."dynamic-${domain}".secrets.porkbun_secret_api_key.decrypted.path;

  ddns = pkgs.writeShellApplication {
    name = "porkbun-ddns";
    runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils pkgs.util-linux ];
    text = ''
      DOMAIN=${lib.escapeShellArg domain}
      SUBDOMAIN=${lib.escapeShellArg subdomain}
      TTL=600
      API="https://api.porkbun.com/api/json/v3"

      # Raw key files, one value each.
      API_KEY="$(${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg keyPath})"
      SECRET="$(${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg secretPath})"
      API_KEY="''${API_KEY//[[:space:]]/}"
      SECRET="''${SECRET//[[:space:]]/}"

      if [ -z "$API_KEY" ] || [ -z "$SECRET" ]; then
        echo "porkbun credentials are empty" >&2
        exit 1
      fi

      auth="$(${lib.getExe pkgs.jq} -nc \
        --arg k "$API_KEY" --arg s "$SECRET" \
        '{apikey:$k,secretapikey:$s}')"

      # Credentials travel in the JSON body (stdin), never in argv.
      post() {
        ${lib.getExe pkgs.curl} -sS --fail-with-body --max-time 30 \
          --retry 3 --retry-delay 5 \
          -H 'Content-Type: application/json' \
          -H "Idempotency-Key: $(${lib.getExe' pkgs.util-linux "uuidgen"})" \
          --data @- "$1"
      }

      # 1. Caller IP + credential check.
      ping_resp="$(post "$API/ping" <<<"$auth")"
      if [ "$(${lib.getExe pkgs.jq} -r '.status' <<<"$ping_resp")" != "SUCCESS" ]; then
        echo "porkbun ping failed: $ping_resp" >&2
        exit 1
      fi
      IP="$(${lib.getExe pkgs.jq} -r '.yourIp' <<<"$ping_resp")"
      if [ -z "$IP" ] || [ "$IP" = "null" ]; then
        echo "porkbun returned no caller IP: $ping_resp" >&2
        exit 1
      fi

      # 2. Current A record.
      cur_resp="$(post "$API/dns/retrieveByNameType/$DOMAIN/A/$SUBDOMAIN" <<<"$auth")"
      cur_status="$(${lib.getExe pkgs.jq} -r '.status' <<<"$cur_resp")"
      if [ "$cur_status" = "SUCCESS" ]; then
        count="$(${lib.getExe pkgs.jq} -r '.records | length' <<<"$cur_resp")"
      elif [ "$(${lib.getExe pkgs.jq} -r '.code // empty' <<<"$cur_resp")" = "NOT_FOUND" ]; then
        count=0
      else
        echo "porkbun retrieve failed: $cur_resp" >&2
        exit 1
      fi

      # 3. Compare before writing.
      if [ "$count" -gt 0 ]; then
        old="$(${lib.getExe pkgs.jq} -r '.records[0].content' <<<"$cur_resp")"
        if [ "$old" = "$IP" ]; then
          echo "$SUBDOMAIN.$DOMAIN already points at $IP; nothing to do"
          exit 0
        fi
        body="$(${lib.getExe pkgs.jq} -nc \
          --arg k "$API_KEY" --arg s "$SECRET" \
          --arg c "$IP" --argjson ttl "$TTL" \
          '{apikey:$k,secretapikey:$s,content:$c,ttl:$ttl}')"
        write_resp="$(post "$API/dns/editByNameType/$DOMAIN/A/$SUBDOMAIN" <<<"$body")"
      else
        body="$(${lib.getExe pkgs.jq} -nc \
          --arg k "$API_KEY" --arg s "$SECRET" \
          --arg n "$SUBDOMAIN" --arg c "$IP" --argjson ttl "$TTL" \
          '{apikey:$k,secretapikey:$s,name:$n,type:"A",content:$c,ttl:$ttl}')"
        write_resp="$(post "$API/dns/create/$DOMAIN" <<<"$body")"
      fi

      # 4. API status + delegation warning.
      if [ "$(${lib.getExe pkgs.jq} -r '.status' <<<"$write_resp")" != "SUCCESS" ]; then
        echo "porkbun write failed: $write_resp" >&2
        exit 1
      fi

      warnings="$(${lib.getExe pkgs.jq} -r '(.warnings // [])[]' <<<"$write_resp")"
      if [ -n "$warnings" ]; then
        echo "porkbun warning (stored, may not resolve yet): $warnings" >&2
      fi

      echo "updated $SUBDOMAIN.$DOMAIN -> $IP (TTL $TTL)"
    '';
  };
in
{
  secrix.services."dynamic-${domain}".secrets = {
    porkbun_api_key.encrypted.file = "${self}/secrets/porkbun-api-bargman";
    porkbun_secret_api_key.encrypted.file =
      "${self}/secrets/porkbun-api-bargman-secret-key";
  };

  systemd.services."dynamic-${domain}" = {
    description = "Porkbun dynamic DNS for ${domain}";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe ddns;
    };
  };

  systemd.timers."dynamic-${domain}" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "60m";
      RandomizedDelaySec = "5m";
      Unit = "dynamic-${domain}.service";
    };
  };
}
