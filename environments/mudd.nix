{ config, pkgs, ... }:

{
  environment.systemPackages = [
    # blightmud 5.7.0 in the unstable pin is missing oniguruma/libgit2 in
    # buildInputs while the global cargo-setup-hook forces
    # RUSTONIG_SYSTEM_LIBONIG — onig_sys panics on the absent .pc. Upstream
    # nixpkgs fixed this in 5.7.1 (buildInputs += oniguruma, libgit2);
    # mirror it until the pin carries the fix. Retire after the next
    # nixpkgs_unstable bump.
    (pkgs.blightmud.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [
        pkgs.oniguruma
        pkgs.libgit2
      ];
    }))
  ];
}
