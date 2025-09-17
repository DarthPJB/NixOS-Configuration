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
      doCheck = true;
      buildInputs = [ pkgs.gnucap ];

      buildPhase = ''
        # Run gnucap simulation
        echo "Running gnucap on resistor circuit..."
        gnucap -b circuit.cir > results.out
      '';

      checkPhase = ''
        echo "Running checkPhase..."
        if grep -q "V(out)" results.out; then
awk '/#.*V\(out\)/ {f=1; next} f&&/^[0-9]/ {if ($2 >= 2.4 && $2 <= 2.6) exit 0; else exit 1}' results.out || { echo "Test failed: V(out) not within 2.4V-2.6V"; exit 1; }
          echo "Test passed: V(out) is approximately 2.5V"
        else
          echo "Test failed: V(out) not found in results.out"
          #cat results.out
          exit 1
        fi
      '';

      installPhase = ''
        mkdir -p $out
        cp results.out $out/
      '';
    };
  };
}
