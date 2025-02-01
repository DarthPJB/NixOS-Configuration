{ self, lib, config, pkgs, ... }:
let
  inherit (builtins) map;
  inherit (lib) mkOption getExe;
  inherit (lib.types) listOf str;

  cfg = config.boot.raspi;
  kernelSrc = pkgs.fetchFromGitHub {
    owner = "raspberrypi";
    repo = "linux";
    rev = "cd92a9591833ea06d1f12391f6b027fcecf436a9";
    hash = "sha256-+9KpjeYFUeH0YCf40GICfTr/Tz++eNbUPenDOeKy+Vc=";
  };
in
{
  options.boot.raspi.dtoverlays = mkOption {
    type = listOf str;
    default = [ ];
  };

  config = {
    hardware = {
      deviceTree = {
        /*    enable = true;
        filter = "*rpi-3*.dtb";
        overlays = map (name: {
          inherit name;
          dtsFile = pkgs.runCommand "dtoverlay-${name}" {} ''
            cd ${kernelSrc}/arch/arm/boot/dts/overlays
            ${getExe ovmerge} ${name}  > $out
          '';
        }) cfg.dtoverlays; */
      };
    };
  };
}
