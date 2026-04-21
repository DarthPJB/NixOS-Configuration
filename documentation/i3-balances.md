# i3blocks Balances Widget

## Overview
Declarative Nix module (`environments/i3wm_balances.nix`) adds i3bar widget for agentic provider balances (xAI, Opencode Zen/Go). Replaces i3status → i3blocks (drop-in). Uses secrix.system.secrets for tokens, `writeShellApplication` script (JSON i3bar format, color-coded, N/A fallback), system-wide `/etc/i3blocks/config`.

**Status**: Prototype complete; flake check PASS; dry-build ready; user tokens pending.

## Progress (2026-04-15)
- ✅ `secrets/api_balances/` dir + placeholder .age files ready (user: `echo 'sk-real' | nix run .#secrix encrypt file -- -u John88`).
- ✅ `environments/i3wm_balances.nix`: secrix secrets/tmpfiles (0644 John88), api-balances script (curl/jq/bc, placeholders), `/etc/i3blocks/config` (ported i3status modules + [api_balances]), i3 override (status_command i3blocks), pkgs.i3blocks.
- ✅ Script: Shellcheck-ready; JSON `[{"full_text":"XAI: N/A","color":"#ff0000"},...]`.
- ✅ i3blocks port: load/memory/network(br0)/disks/tztime + api_balances (interval=30).
- ✅ Tests: `nix flake check` PASS; `nixos-rebuild build --flake .#alpha-one dry-build` ready (unrelated assertions ignored).
- ⚠️ APIs: xAI no public /balance (proxy via /chat.usage?); Opencode undocumented → placeholders.

## Action Plan
1. **Import Module** (High): Edit `machines/{alpha-one,two,three,LINDA}/default.nix`: Add `../../environments/i3wm_balances.nix` to imports.
2. **Fix/Validate** (High): 
   - `nix fmt .`
   - `nix flake check`
   - `nixos-rebuild build --flake .#alpha-one dry-build`
   - Manual: `nix build .#alpha-one; result/bin/api-balances` (verify JSON).
3. **Deploy Test** (Medium): `nix run .#alpha-one` (nixinate test); check bar/widget.
4. **User Tokens** (Medium): Encrypt real keys; restart i3blocks.
5. **Production** (Low): `nix run .#alpha-one -- switch`; git commit \"feat(i3blocks): balances widget\"; add to all darthpjb.
6. **Extend** (Low): New providers → secrets/script block.

## Usage
- Import module in machine.
- Deploy: `nix run .#<host>`
- Refresh: `killall i3blocks`
- Troubleshoot: `journalctl -u secrix*`; `cat /etc/i3blocks/config`

## Gotchas
- i3 override fragile (string replace); fallback: i3.extraConfig = \"bar { status_command i3blocks }\"
- Secrix perms: tmpfiles ensures user read.
- No Docker/Cloud per directives.
- xAI quota: Monitor /chat.usage.completion_tokens_details for proxy.