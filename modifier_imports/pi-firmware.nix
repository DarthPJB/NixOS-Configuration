{ self
, lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkOption;
  inherit (lib.types) listOf str;
in
{
  options.boot.raspi.dtoverlays = mkOption {
    type = listOf str;
    default = [ ];
  };

  config = {
    hardware = {
      deviceTree = {
        # WIP: Pi firmware overlay implementation (commented out — needs ovmerge tool)
        # When revived, will need: builtins.map, lib.getExe, cfg = config.boot.raspi, kernelSrc fetch
        /*
          enable = true;
          filter = "*rpi-3*.dtb";
          overlays = map (name: {
            inherit name;
            dtsFile = pkgs.runCommand "dtoverlay-${name}" {} ''
              cd ${kernelSrc}/arch/arm/boot/dts/overlays
              ${getExe ovmerge} ${name}  > $out
            '';
          }) cfg.dtoverlays;
        */
      };
    };
  };
}
