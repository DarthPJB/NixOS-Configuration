{ pkgs }:

let
  vimrc = builtins.readFile ./init.vim;
  plugins = import ./plugins.nix { inherit pkgs; };
in
{
  customRC = vimrc;
  vam = {
    knownPlugins = pkgs.vimPlugins // plugins;

    pluginDictionaries = [
      { name = "vim-fugitive"; }
      { name = "vim-commentary"; }
      { name = "vim-markdown"; }
      { name = "vim-surround"; }
      { name = "vim-indent-object"; }
      # { name = "vim-colors-solarized"; }
      { name = "syntastic"; }
      { name = "argtextobj-vim"; }
      # { name = "vim-jade"; }
      { name = "vim-pug"; }
      { name = "neomake"; }
      { name = "vim-nix"; }
      { name = "dhall-vim"; }
      { name = "elm-vim"; }
      { name = "rust-vim"; }
      { name = "typescript-vim"; }
    ] ++ pkgs.lib.attrsets.mapAttrsToList (n: _: { name = n; }) plugins;
  };
}
