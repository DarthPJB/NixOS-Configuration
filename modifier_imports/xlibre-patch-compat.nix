# xlibre-patch-compat — parent-side repair for the xlibre-overlay input.
#
# The xlibre-overlay (codeberg takagemacoed/xlibre-overlay) builds
# xlibre-xserver by overriding `xorg-server` and inheriting the patch
# stack wholesale: `patches = prevAttrs.patches or [ ] ++ ...`. Those
# patches belong to xorg-server 21.1.x. The unstable pin's stack grew
# `revert-damage-unlink-abi-break.patch`, whose end state XLibre 25.2.3
# already contains — patch(1) answers "Reversed (or previously applied)
# patch detected" and the xserver build dies mid-patchPhase.
#
# Dropping the patch is semantically inert (the revert is a no-op against
# this source) and restores the build. Must be listed AFTER the
# xlibre-overlay modules so this filter wraps their result. Retire when
# upstream xlibre-overlay stops inheriting foreign patch stacks.
{ lib, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      xorg-server = prev.xorg-server.overrideAttrs (old: {
        patches = builtins.filter
          (
            p: !(lib.hasSuffix "revert-damage-unlink-abi-break.patch" (toString p))
          )
          (old.patches or [ ]);
      });
    })
  ];
}
