{
  description = "A Nix flake to generate dotted paper SVG using Bash";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux"; # Adjust for your system if needed
      pkgs = nixpkgs.legacyPackages.${system};

      # Default parameters for the SVG
      defaultParams = {
        pageWidth = 210; # A4 width in mm
        pageHeight = 297; # A4 height in mm
        dotDistance = 5; # Distance between dots in mm
        dotRadius = 0.3; # Radius of each dot in mm
        outputFile = "dotted-paper.svg";
      };

      # Function to generate SVG derivation with customizable parameters
      mkDottedPaperSvg = params:
        let
          mergedParams = defaultParams // params;
          # Script to generate SVG
          generateSvgScript = pkgs.writeText "generate_dotted_paper.sh" ''
            #!/bin/sh
            width=${toString mergedParams.pageWidth}
            height=${toString mergedParams.pageHeight}
            dot_distance=${toString mergedParams.dotDistance}
            dot_radius=${toString mergedParams.dotRadius}
            output_file=${mergedParams.outputFile}

            cat <<EOF > $output_file
            <?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <svg width="''${width}mm" height="''${height}mm" viewBox="0 0 ''${width} ''${height}" xmlns="http://www.w3.org/2000/svg">
            EOF

                        for x in $(seq 0 $dot_distance $width); do
                            for y in $(seq 0 $dot_distance $height); do
                                echo "<circle cx=\"$x\" cy=\"$y\" r=\"$dot_radius\" fill=\"black\"/>" >> $output_file
                            done
                        done

                        cat <<EOF >> $output_file
            </svg>
            EOF
          '';
        in
        pkgs.stdenv.mkDerivation {
          name = "dotted-paper-svg";
          buildInputs = [ pkgs.bash ];
          dontUnpack = true; # No source to unpack
          buildPhase = ''
            bash ${generateSvgScript}
          '';
          installPhase = ''
            mkdir -p $out
            cp ${mergedParams.outputFile} $out/
          '';
        };

    in
    {
      lib.mkDottedPaperSvg = mkDottedPaperSvg;
      packages.${system} = {
        default = mkDottedPaperSvg { };
        customA5 = mkDottedPaperSvg {
          pageWidth = 148;
          pageHeight = 210;
          dotDistance = 10;
          dotRadius = 0.5;
          outputFile = "dotted-paper-a5.svg";
        };
      };
    };
}
