{ pkgs, ... }:

{
  environment.systemPackages = with pkgs;
    let
        myNvim = pkgs.neovim.override {
          vimAlias = true;
          configure = (import ./chloe/nvim { inherit pkgs; });
        };
    in [ myNvim ];
}
