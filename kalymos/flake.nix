{
  description = "A Nix flake to generate dotted paper SVG using Inkscape";

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
        dotRadius = 0.5; # Radius of each dot in mm
        outputFile = "dotted-paper.svg";
      };

      # Function to generate SVG derivation with customizable parameters
      mkDottedPaperSvg = params:
        let
          mergedParams = defaultParams // params;
          # Script to generate SVG template
          generateSvgScript = pkgs.writeText "generate_dotted_paper.sh" ''
            #!/bin/sh
            width=${toString mergedParams.pageWidth}
            height=${toString mergedParams.pageHeight}
            dot_distance=${toString mergedParams.dotDistance}
            dot_radius=${toString mergedParams.dotRadius}
            output_file=${mergedParams.outputFile}

            cat <<EOF > template.svg
            <svg width="''${width}mm" height="''${height}mm" viewBox="0 0 ''${width} ''${height}" xmlns="http://www.w3.org/2000/svg">
            EOF

            for x in \$(seq 0 $dot_distance \$(echo "\$width - 1" | bc)); do
                for y in \$(seq 0 $dot_distance \$(echo "\$height - 1" | bc)); do
                    echo "<circle cx='\''\$x'\'' cy='\''\$y'\'' r='\''$dot_radius'\'' fill='black'/>" >> template.svg
                done
            done

            cat <<EOF >> template.svg
            </svg>
            EOF

            # Use Inkscape to process the SVG
            ${pkgs.inkscape}/bin/inkscape --export-type=svg --export-filename=$output_file template.svg
          '';
        in
        pkgs.stdenv.mkDerivation {
          name = "dotted-paper-svg";
          buildInputs = [ pkgs.inkscape pkgs.bash ];
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
      # Expose a default package with default parameters
      packages.${system}.default = mkDottedPaperSvg {};

      # Expose a function for custom parameters
      lib.mkDottedPaperSvg = mkDottedPaperSvg;

      # Example custom package with different parameters
      packages.${system}.customA5 = mkDottedPaperSvg {
        pageWidth = 148; # A5 width
        pageHeight = 210; # A5 height
        dotDistance = 10; # Larger dot spacing
        dotRadius = 0.8; # Larger dots
        outputFile = "dotted-paper-a5.svg";
      };
    };
}
