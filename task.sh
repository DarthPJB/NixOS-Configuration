#! /bin/sh

echo "Pull the latest version"
git pull origin

echo "Copy dotfiles into place"
cp ./dotfiles/* /home/pokej/  -r
#cp ./dotfiles/ /home/pokej/ -r

echo "Push config into position"
cp ./config/* /etc/nixos/ -r

echo "Generate new Nix-config"
nixos-rebuild dry-build
