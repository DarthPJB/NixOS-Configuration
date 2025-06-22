{ pkgs, ... }:
{
  environment.systemPackages = with pkgs;
    [
      pkgs.emacs
      pkgs.nix-top
    ];
}
