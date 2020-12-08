#! /bin/sh

# Pull the latest version
git pull origin

# Copy dotfiles into place
cp ./dotfiles/* ~/ -r
cp ./dotfiles/.* ~/ -r

# Push config into position
cp ./config/* /etc/nixos/ -r

# Generate new Nix-config
nixos-rebuild dry-build
