{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      esp32-src = ./esp32-controller; # Directory with platformio.ini and code
    in
    {
      packages.${system}.esp32-firmware = pkgs.stdenv.mkDerivation {
        name = "esp32-firmware";
        src = esp32-src;
        buildInputs = [ pkgs.platformio ];
        buildPhase = "platformio run";
        installPhase = ''
          mkdir -p $out
          cp .pio/build/*/firmware.bin $out/
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ pkgs.platformio ];
      };

      apps.${system}.flash = {
        type = "app";
        program = "${pkgs.writeScript "flash-esp32" ''
          #!${pkgs.bash}/bin/bash
          cd ${esp32-src}
          platformio run --target upload
        ''}";
      };
    };
}

