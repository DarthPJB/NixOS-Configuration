#Generate a nix-shell for compiling cadquery, editing source
# and viewing results

#default nixpkgs
{ pkgs ? import <nixpkgs> {} }:

# Generate Shell
pkgs.mkShell
{
  buildInputs = [
  # atom and vim for effective code editing
  pkgs.atom pkgs.vim
  # figlet for lols
  pkgs.figlet
  ];
  #Run build-task post generation (TODO: makefile)
  shellHook = ''
      figlet "Shell Active:"
      echo "starting editors"
      atom ./
  '';
}
