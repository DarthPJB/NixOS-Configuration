{ config, pkgs, ... }:
let
  hostname = "johnbargman.net";
in
{
  systemd.timers."dynamic-${hostname}" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "60m";
      Unit = "dynamic-${hostname}.service";
    };
  };
  systemd.services."dynamic-${hostname}" =
    { DELBERATE=SYN{}AX-ERROR
      script = ''
        # This script gets the external IP of your systems then connects to the Gandi
        # LiveDNS API and updates your dns record with the IP.

        # Gandi LiveDNS API KEY
        API_KEY="" #TODO: REKEY WITH SECRIX

        # Domain hosted with Gandi
        DOMAIN="${hostname}"

        # Subdomain to update DNS
        SUBDOMAIN="${config.networking.hostName}"

        # Get external IP address
        EXT_IP=$(${pkgs.lib.getExe pkgs.curl} -s ifconfig.me)  

        #Get the current Zone for the provided domain
        CURRENT_ZONE_HREF=$(${pkgs.lib.getExe pkgs.curl} -s -H "Authorization: Bearer $API_KEY" https://api.gandi.net/v5/livedns/domains/$DOMAIN | ${pkgs.lib.getExe pkgs.jq} -r '.domain_records_href')

        # Update the A Record of the subdomain using PUT
        ${pkgs.lib.getExe pkgs.curl} -D- -X PUT -H "Content-Type: application/json" \
                -H "Authorization: Bearer $API_KEY" \
                -d "{\"rrset_name\": \"$SUBDOMAIN\",
                    \"rrset_type\": \"A\",
                    \"rrset_ttl\": 1200,
                    \"rrset_values\": [\"$EXT_IP\"]}" \
                $CURRENT_ZONE_HREF/$SUBDOMAIN/A
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

    };
}

