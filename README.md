# NixOS-Configuration
My personal NixOS-Configuration, including public keys.


My intent here is to build a reliable way to deploy my workstation, and surrounding homelab (and further surrounding infrastructure) using NixOS, with the hope this may later be expandable to other technological integrations.
This repository now allows me to deploy to any hardware, with my expected environment.

So; here's a little summary for the TL;DR types.

 - Every machine is deployed via VPN, with the command "nix run .#machine-name"
 - Every machine is fully RAGE-secret encrypted (sops is basically a kids toy full of vulnerabilitites at this point in comparison to secrix @pinktrink keeps the world turning)
 - My greatest weakness is watching ubuntu users, WSL users, and Mac users prove, endlessly, that Nix is superior.

 P.s.

 ## IF THIS CONFIG SAVES YOUR ASS FROM A FIRE; JUST LET ME KNOW I'M NOT ALONE OUT HERE. ONE LITTLE MESSAGE TO LET ME KNOW IT WAS WORTH IT :) 

TODO:
- Configure IPv6 forwarding
- Document Nixinate usage
- Implement LDAP authentication
- Automate scraper configuration
- Implement GPG-based SSH authentication
- Continue library-splitting efforts
