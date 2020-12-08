#! /bin/sh

echo "Pull the latest version"
git pull origin

echo "Copy dotfiles into place"
cp -a -r ./dotfiles/.background-image /home/pokej/ 
cp -a -r ./dotfiles/.config/* /home/pokej/.config/ 
#cp ./dotfiles/ /home/pokej/ -r

echo "Push config into position"
sudo cp -r -a ./config/* /etc/nixos/

echo "Generate new Nix-config"
nixos-rebuild dry-build
