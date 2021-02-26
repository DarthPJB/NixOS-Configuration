{ config, pkgs, ... }:


let
  baseconfig = { allowUnfree = true; };
  unstableTarball =
    fetchTarball
      https://github.com/NixOS/nixpkgs-channels/archive/nixos-unstable.tar.gz;
  unstable = import unstableTarball
  {
    config = baseconfig;
  };
in
{
	environment.systemPackages = with pkgs; [
		gimp
		inkscape
		unstable.blender
		solvespace
		openscad
		freecad
		krita
	#	tiled
	];
}
