# i3 Dark Theme by Default — PLAN

**Date:** 2026-10-17
**Status:** Proposed — awaiting approval
**Target:** `environments/i3wm_darthpjb.nix` stack (theming lives in `environments/i3wm.nix`, imported at `i3wm_darthpjb.nix:9`)

## Goal

Make the i3 desktop dark by default everywhere: GTK2/3/4 apps, Qt apps,
libadwaita apps, icon theme, cursors, and i3 window-manager chrome
(titlebar decorations + i3bar/i3status bar).

## Decisions (user-confirmed 2026-10-17)

| Decision | Choice |
|---|---|
| Scope | Shared `environments/i3wm.nix` (affects all i3 machines, incl. display-1/2) |
| GTK theme | **Vimix-dark-ruby** (`pkgs.vimix-gtk-themes` override) — Arc rejected (partially deprecated); Materia-dark replaced after theme survey; Vimix is Materia-derived, actively maintained (2025-06), adds dark+ruby-red accent and GTK4 assets |
| Icon theme | **Papirus-Dark** |
| i3 chrome | Explicit dark `client` + `bar { colors }` palette, ruby-red accent |
| Goldens | Regeneration authorized for affected machines |

## Root causes (current "dark" config is broken in 4 places)

1. `GTK_THEME = "Arc-Dark"` set (`i3wm.nix:39`) but `arc-theme` is **not** in
   `environment.systemPackages` → GTK falls back to stock Adwaita (light).
2. `GTK_ICON_THEME = "Papirus-Red"` (`i3wm.nix:41`) is wrong twice: `papirus-icon-theme`
   ships only `Papirus`/`Papirus-Dark`/`Papirus-Light` (verified in store), and GTK never
   reads `GTK_ICON_THEME` — the real key is `gtk-icon-theme-name` (settings.ini/dconf).
3. `environment.etc."gtk-3.0/gtk-4.0/settings.ini"` writes `/etc/gtk-3.0/…`, but NixOS sets
   `XDG_CONFIG_DIRS = "/etc/xdg"` (`nixos/modules/programs/environment.nix:34`), so GTK3/4
   never read them → `gtk-application-prefer-dark-theme=1` is dead config.
4. No `org.gnome.desktop.interface color-scheme = prefer-dark` → libadwaita/GTK4 apps and
   Chromium/Electron (via xdg-desktop-portal-gtk settings portal) stay light.

Verified working today: GTK2 `/etc/gtk-2.0/gtkrc` IS read (gtk2 built with
`sysconfdir=/etc`); Qt stack (`QT_STYLE_OVERRIDE=Adwaita-Dark` + adwaita-qt/qt6);
greeter (bargman-cinematic); root window (`xsetroot -solid #000000`);
cursor theme (`bargman-theming.nix`).

## Theme selection rationale (survey 2026-10-17)

Full GTK theme catalogue of the pinned `nixpkgs_stable` was surveyed (~70 packages).
Pure-black and dark/red/amber candidates were evaluated against maintenance status:

- Fausto-Korpsvart family (Nightfox/Gruvbox/Kanagawa/TokyoNight) — **archived Oct 2026**
  (same deprecation issue as Arc).
- `amber-theme` — upstream README: "NO LONGER MAINTAINED".
- `materia-theme` — last release 20210322, no GTK4 assets.
- vinceliuice family (Graphite/Colloid/Vimix/Orchis) — **actively maintained**; GTK2+3+4.
- **Vimix-Dark-Ruby chosen**: Materia-derived (familiar look), maintained, dark + ruby
  accent, ships `gtk-4.0` assets so GTK4/libadwaita can be themed.
- Exact dir name verified from upstream `install.sh`:
  `THEME_DIR=${name}${color}${size}${theme}` → `Vimix-dark-ruby` (lowercase suffixes).
- vimix accent list: `doder(blue default)|beryl|ruby|amethyst|jade|grey`; colour:
  `standard|light|dark`; tweaks: `flat|grey|mix|translucent` (optional `mix` deepens
  dark-mode background — consider later if default dark grey is too light).

## Changes — all in `environments/i3wm.nix`

1. **systemPackages:** add

   ```nix
   (pkgs.vimix-gtk-themes.override {
     themeVariants = [ "ruby" ];    # installs Vimix-dark-ruby
     colorVariants = [ "dark" ];
   })
   ```

   Keep `adwaita-qt`, `adwaita-qt6`, `papirus-icon-theme`.
2. **sessionVariables:**
   - `GTK_THEME = "Vimix-dark-ruby"` (replaces Arc-Dark)
   - drop `GTK_ICON_THEME` (no consumer)
   - keep `QT_STYLE_OVERRIDE = "Adwaita-Dark"`
   - add `ADW_DEBUG_COLOR_SCHEME = "prefer-dark"` (belt-and-braces for libadwaita apps)
3. **GTK settings at the paths GTK actually reads:**
   - `environment.etc."xdg/gtk-3.0/settings.ini"`: `gtk-theme-name=Vimix-dark-ruby`,
     `gtk-icon-theme-name=Papirus-Dark`, `gtk-application-prefer-dark-theme=1`
   - `environment.etc."xdg/gtk-4.0/settings.ini"`: same keys
   - `environment.etc."gtk-2.0/gtkrc"`: keep location (verified read),
     `gtk-theme-name="Vimix-dark-ruby"`
4. **dconf user database** (same pattern as `hyperland.nix:24`):

   ```nix
   programs.dconf.profiles.user.databases = [{
     settings."org/gnome/desktop/interface" = {
       gtk-theme = "Vimix-dark-ruby";
       icon-theme = "Papirus-Dark";
       cursor-theme = "BargmanCinematic-Cursors";
       cursor-size = 24;
       color-scheme = "prefer-dark";
     };
   }];
   ```

   This is what flips libadwaita/GTK4 and Chromium/Vivaldi (portal `color-scheme`) dark.
5. **Libadwaita/GTK4 full Vimix styling** (declarative equivalent of upstream
   `install.sh -l`): link the theme's gtk-4.0 assets into the system XDG config dir:

   ```nix
   environment.etc."xdg/gtk-4.0/gtk.css".source =
     "${vimixTheme}/share/themes/Vimix-dark-ruby/gtk-4.0/gtk.css";
   environment.etc."xdg/gtk-4.0/gtk-dark.css".source = …/gtk-dark.css;
   environment.etc."xdg/gtk-4.0/assets".source = …/gtk-4.0/assets;
   ```

   GTK4/libadwaita loads `gtk.css`/`gtk-dark.css` from `XDG_CONFIG_DIRS` (`/etc/xdg`).
6. **i3 config (`xConfig`):** explicit dark palette — `client.focused` /
   `focused_inactive` / `unfocused` / `urgent` / `placeholder` + `client.background`,
   and `bar { colors { background / statusline / separator / *_workspace } }`.
   Palette: backgrounds `#1c1c1c`/`#2b2b2b`/`#444444`, accent ruby `#E53950`
   (tune to taste at visual check), text `#d0d0d0`/`#ffffff`, urgent `#900000`.
   **Constraint:** keep the `status_command i3status` line verbatim —
   `i3wm_balances.nix:137` string-replaces that exact line with `i3blocks`.

Notes:
- Out of scope: rofi (default theme is dark), terminology (EFL, default dark),
  display-1's alacritty `theme.toml` (already `#000000`).
- Flag only (separate env): `hyperland.nix:28` sets `icon-theme = "Flat-Remix-Red-Dark"`
  which also looks like a phantom theme name — not touched here.

## Blast radius

Machines importing `i3wm.nix` (directly or via `i3wm_darthpjb.nix`):
alpha-one, alpha-two, alpha-three, LINDA, terminal-zero, terminal-nx-01,
pillar-of-autum, display-1, display-2, plus the `bargman-greeter-vm` system
(`flake.nix:838`) and `bargman-greeter-login-test` check.

## Golden regeneration (user-authorized 2026-10-17)

`environment.systemPackages` IS serialized (`lib/serialize-config.nix` safeSections) —
adding `vimix-gtk-themes` moves goldens. `sessionVariables`, `programs.dconf`,
`environment.etc`, and `services.xserver` are NOT serialized — those changes are golden-neutral.

Regenerate and validate these 10 goldens:

```
alpha-one  alpha-two  alpha-three  LINDA  terminal-zero  terminal-nx-01
pillar-of-autum  display-1  display-2  bargman-greeter-vm
```

```bash
nix run .#dump-config -- <machine> | jq -S . > goldens/<machine>.json
nix run .#validate-goldens -- <machine>
```

## Verification

1. `nix flake check` (formatting via `nixpkgs-fmt --check`, deadnix) — do NOT run
   `nix fmt` on the whole codebase.
2. Confirm theme dir name from build output:
   `ls $(nix build --print-out-paths --no-link .#nixosConfigurations.alpha-one.pkgs.vimix-gtk-themes)/share/themes`
   (expect `Vimix-dark-ruby`) — do before wiring `gtk-theme-name`.
3. Per-machine goldens after regeneration (deploy blocked on mismatch).
4. `nix build .#checks.x86_64-linux.bargman-greeter-login-test -L` — greeter
   screenshot golden must stay unchanged (greeter untouched).
5. Deploy one machine and visually confirm dark: pavucontrol (GTK3), a GTK4/libadwaita
   app, a Qt app, Vivaldi/Chromium, rofi, i3bar + titlebar chrome.

## Deployment flow

1. Goldens regenerated + validated for all 10
2. WireGuard keys present (standard flow)
3. Deploy per machine with usual caution
