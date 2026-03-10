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

## Adding a New Machine

1. Imperatively install NixOS on new host (`nixos-install`).
2. `$ scp user@host-ip:/etc/nixos/* ./machines/new-host/; mv machines/new-host/configuration.nix machines/new-host/default.nix`
3. Edit `default.nix`: `{ config, lib, pkgs, self, hostname, ... }: { networking.hostName = hostname; /* imports, envs, secrix.services.wireguard... */ }`
4. `$ scp user@host-ip:/etc/ssh/ssh_host_ed25519.pub ./secrets/public_keys/host_keys/new-host.pub`
5. Local WG: `$ wg genkey | tee priv | wg pubkey > pub; nix run .#secrix create ./secrets/wireguard/wg_new-host -- -u John88 < priv`
6. `./lib/wg_peers.nix` consumes the attrset from `./cortex-alpha/default.nix` -  peerlist : `"new-host" = "90";` (pick free IP 10.88.127.X)
7. `flake.nix`: `new-host = mkX86_64 "new-host" { host = "10.88.127.90"; };`
8. Test: `$ nix fmt; nix flake check; nixos-rebuild build --flake .#new-host`

**Notes:** 
1. First deploy via public IP using the settings `sshUser` `sshPort` and `host` under nixinate in flake.nix: then `nix run .#new-host` to 'test' deploy. 
2. Then setup deploy user/VPN.

## VPN
simplified heavily by using the module `./modules/enable-wg.nix`


## TODO
- Configure IPv6 forwarding
- Document Nixinate usage
- Make ``enable-wg.nix``, ``cortex-alpha/default.nix`` and ``wg_peers.nix`` both consume the same IP postfix-configuration.
- Implement LDAP authentication
- Automate scraper configuration
- Implement GPG-based SSH authentication
- Continue library-splitting efforts
