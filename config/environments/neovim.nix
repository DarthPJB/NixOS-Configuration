{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs;
    let
        myNvim = inputs.nixpkgs_2205.legacyPackages.x86_64-linux.neovim.override {
          vimAlias = true;
          configure = (import ./chloe/nvim { inherit pkgs; });
        };
    in [ myNvim ];
}
