#! /bin/sh

echo "Pull the latest version"
git pull origin

echo "Copy dotfiles into place"
cp -a./dotfiles/.background-image /home/pokej/ -r
cp -a ./dotfiles/.config/* /home/pokej/.config/ -r
#cp ./dotfiles/ /home/pokej/ -r

echo "Push config into position"
sudo cp ./config/* /etc/nixos/ -r

echo "Generate new Nix-config"
nixos-rebuild dry-build
