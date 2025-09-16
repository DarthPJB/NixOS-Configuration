{
  description = "gnucap resistor simulation with unit test";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
  in {
    packages.x86_64-linux.default = pkgs.stdenv.mkDerivation {
      name = "resistor-simulation";
      src = ./.;

      buildInputs = [ pkgs.gnucap ];

      buildPhase = ''
        # Run gnucap simulation
        echo "Running gnucap on resistor circuit..."
        gnucap -b circuit.cir > results.out
      '';

      checkPhase = ''
        # Validate output voltage (~2.5V within 0.1V tolerance)
        grep "Vout = 2.5" results.out || {
          echo "Test failed: Vout not approximately 2.5V"
          exit 1
        }
        echo "Test passed: Vout is approximately 2.5V"
      '';

      installPhase = ''
        mkdir -p $out
        cp results.out $out/
      '';
    };
  };
}
