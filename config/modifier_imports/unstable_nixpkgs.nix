{ config, pkgs, ... }:
{
  # TODO:update this to use overlays on specific packages / find a way to make 'unstable' available at the top level of the config
  baseconfig = { allowUnfree = true; };
  unstableTarball =
    fetchTarball
      https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz;
  unstable = import unstableTarball
  {
    config = baseconfig;
  };
}
