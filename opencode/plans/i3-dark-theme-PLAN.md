# i3 Dark Theme — Colloid Black Darkening — PLAN

**Date:** 2026-10-18
**Status:** Proposed — awaiting approval
**Target:** `environments/i3wm.nix` (shared by `i3wm_darthpjb.nix` stack)

## Context

Base dark theming is **already implemented** (commit `bf7641c` "change the theme a bit"):
`colloid-gtk-theme` override (theme `red`, color `dark`) → `Colloid-Red-Dark`,
settings at `/etc/xdg/gtk-3.0|4.0`, dconf `color-scheme=prefer-dark`,
`ADW_DEBUG_COLOR_SCHEME`, gtk-4.0 css/assets links, i3 client+bar palette,
`i3wm_balances.nix` string-replace fix.

**Remaining problem (user report 2026-10-18):** the theme is not dark enough.
Measured backgrounds (built CSS + colloid palette `_colors.scss`):

| Surface | Current | Measured |
|---|---|---|
| Window bg / base | grey-700 | `#2C2C2C` |
| Sidebar / surface | grey-650 | `#3C3C3C` |
| Titlebar / base-alt | grey-750 | `#242424` |
| OSD / panel | grey-800 | `#212121` |

## Decision (user-confirmed 2026-10-18)

**Option A — Colloid `black` ("Blackness") tweak + darkened i3 palette.**
With `tweaks = [ "black" ]` the same surfaces map to the bottom of Colloid's grey scale
(`background()` in `_colors.scss` + `_color-palette-default.scss`):

| Surface | With black tweak | Hex |
|---|---|---|
| Window bg / base | grey-900 | `#0F0F0F` |
| Sidebar / surface | grey-850 | `#121212` |
| Titlebar / base-alt | grey-950 | `#030303` |
| OSD / panel | `$black` | `#000000` (pure black) |

Verified from upstream `install.sh`: `black` sets `$blackness` at compile time and is
**not** part of the theme dir name (`THEME_DIR = name+theme+color+size+scheme`), so
`GTK_THEME` and all config names stay **`Colloid-Red-Dark`** — zero name churn.

Rationale vs alternatives: LINDA's `nixpkgs_unstable` removed `gtk-engine-murrine`, which
deleted `graphite`/`vimix`/`materia`/`nightfox`/`ant-bloody`/`dracula`/`plata` etc.
(verified `throw` at eval). Murrine-free survivors on **both** pins with a true-black
variant: Colloid, Catppuccin (Colloid fork), Orchis. Colloid is already deployed.

## Changes — `environments/i3wm.nix` only

1. **Override gains the black tweak** (theme name unchanged):

   ```nix
   colloidTheme = pkgs.colloid-gtk-theme.override {
     themeVariants = [ "red" ];
     colorVariants = [ "dark" ];
     tweaks = [ "black" ];   # Blackness: #0F0F0F / #030303 / #000000
   };
   ```

2. **i3 palette darkened** in `xConfig` (keep ruby accent `#E53950`):
   - `client.background`, `client.unfocused`, `client.placeholder`, bar `background`
     and `inactive_workspace`: `#1c1c1c` → `#0F0F0F`
   - `client.focused` bg, `active_workspace` bg: `#2b2b2b` → `#121212`
   - `client.focused_inactive` border/indicator/child: `#444444` → `#030303`
   - bar `separator`: `#444444` → `#121212`; urgent stays `#900000`
   - **Constraint:** keep the `                status_command i3status` line verbatim
     (`i3wm_balances.nix:137` string-replaces that exact string).

No other files change. `GTK_THEME`/settings.ini/dconf/gtk-4.0 links already reference
`Colloid-Red-Dark` and remain valid (name unchanged; the override output is rebuilt with
blackness baked in).

## Known residue (unchanged by this delta)

- **Goldens still stale from `bf7641c`** (added `colloidTheme` to serialized
  `environment.systemPackages`) — this delta does not change package names
  (`colloid-gtk-theme` keeps its versioned name; override flags aren't serialized), but
  the pending regeneration covers both. User-authorized scope (2026-10-17): regenerate
  `alpha-one alpha-two alpha-three LINDA terminal-zero terminal-nx-01 pillar-of-autum
  display-1 display-2 bargman-greeter-vm` (10 goldens).
- Qt stays `Adwaita-Dark` (`~#2E2E2E`) — darkest remaining surface; Kvantum black theme
  is a possible follow-up, out of scope.
- Plan history note: original plan chose Vimix-dark-ruby; replaced at implementation time
  by Colloid because `vimix-gtk-themes` throws on LINDA's pin (murrine removal).

## Verification

1. `nix flake check` (formatting `nixpkgs-fmt --check`, deadnix) — no whole-tree `nix fmt`.
2. Confirm blackness in build output (both pins):
   `grep -o 'background-color: #[0-9A-Fa-f]*' .../Colloid-Red-Dark/gtk-3.0/gtk.css | sort | uniq -c`
   expect `#0F0F0F`/`#030303`/`#000000` dominant, no `#2C2C2C`.
3. Regenerate + `nix run .#validate-goldens -- <machine>` for the 10 goldens.
4. `nix build .#checks.x86_64-linux.bargman-greeter-login-test -L` — greeter screenshot
   must stay unchanged.
5. Visual on one machine: GTK3 (pavucontrol), GTK4/libadwaita, Qt, Vivaldi/Chromium,
   i3 bar + titlebars — all near-black with red accent.

## Deployment flow

1. Goldens regenerated + validated for all 10
2. WireGuard keys present (standard flow)
3. Deploy per machine with usual caution
