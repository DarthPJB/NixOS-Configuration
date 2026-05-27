{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkDefault
    mkOption
    mkPackageOption
    optionalString
    types
    ;
  ldmcfg = config.services.xserver.displayManager.lightdm;
  cfg = ldmcfg.greeters.webkit2;
in
{
  options.services.xserver.displayManager.lightdm.greeters.webkit2 = {
    enable = mkEnableOption "lightdm-webkit2-greeter as the LightDM greeter";

    package = mkPackageOption pkgs "lightdm-webkit2-greeter" {
      extraDescription = ''
        This package must provide the `lightdm-webkit2-greeter` executable and
        its `.desktop` entry.
      '';
    };

    theme = {
      package = mkPackageOption pkgs "lightdm-webkit-theme" {
        extraDescription = ''
          This package must provide the selected theme under
          `/share/lightdm-webkit/themes/<name>`.
        '';
      };

      name = mkOption {
        type = types.str;
        description = ''
          Name of the theme directory to use for the lightdm webkit greeter.
        '';
      };
    };

    cursorTheme = {
      package = mkPackageOption pkgs "adwaita-icon-theme" { };

      name = mkOption {
        type = types.str;
        default = "Adwaita";
        description = ''
          Name of the cursor theme to use for the lightdm webkit greeter.
        '';
      };

      size = mkOption {
        type = types.int;
        default = 24;
        description = ''
          Size of the cursor theme to use for the lightdm webkit greeter.
        '';
      };
    };

    settings = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.bool
          types.int
          types.str
        ]
      );
      default = {
        debug_mode = false;
        detect_theme_errors = true;
        screensaver_timeout = 300;
        secure_mode = true;
        time_format = "LT";
        time_language = "auto";
      };
      description = ''
        Values written to the `[greeter]` section of
        `lightdm-webkit2-greeter.conf`.
      '';
    };

    branding = mkOption {
      type = types.submodule {
        options = {
          background_images = mkOption {
            type = types.str;
            default = "";
          };
          logo = mkOption {
            type = types.str;
            default = "";
          };
          user_image = mkOption {
            type = types.str;
            default = "";
          };
        };
      };
      default = { };
      description = ''
        Values written to the `[branding]` section of
        `lightdm-webkit2-greeter.conf`.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra raw configuration appended to `lightdm-webkit2-greeter.conf`.
      '';
    };
  };

  config = mkIf (ldmcfg.enable && cfg.enable) (
    let
      webkitGreeterConf = pkgs.writeText "lightdm-webkit2-greeter.conf" (
        lib.generators.toINI { }
          {
            greeter = cfg.settings // {
              webkit_theme = cfg.theme.name;
            };
            branding = cfg.branding;
          }
        + optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}\n"
      );

      # The greeter package must contain the selected theme in its compiled theme dir.
      wrappedGreeter = cfg.package.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          install -d "$out/share/lightdm-webkit/themes/${cfg.theme.name}"
          cp -r ${cfg.theme.package}/share/lightdm-webkit/themes/${cfg.theme.name}/. \
            "$out/share/lightdm-webkit/themes/${cfg.theme.name}/"
        '';
      });
    in
    {
      services.xserver.displayManager.lightdm.greeter = mkDefault {
        package = wrappedGreeter.xgreeters;
        name = "lightdm-webkit2-greeter";
      };

      environment.systemPackages = [
        cfg.cursorTheme.package
      ];

      environment.etc."lightdm/lightdm-webkit2-greeter.conf".source = webkitGreeterConf;

      xdg.icons.fallbackCursorThemes = [ cfg.cursorTheme.name ];

      systemd.services.display-manager.environment = {
        XCURSOR_THEME = cfg.cursorTheme.name;
        XCURSOR_SIZE = toString cfg.cursorTheme.size;
      };
    }
  );
}
