{ pkgs, ... }:

{
    environment.systemPackages = with pkgs; let
        myNvim = pkgs.neovim.override {
	    vimAlias = true;
	    configure = {
	        vam = {
		    knownPlugins = pkgs.vimPlugins;
		    pluginDictionaries = [
		        { name = "nvim-treesitter"; }
			{ name = "vim-nix"; }
		    ];
		};
	    };
	};
    in [
        myNvim
    ];
}
