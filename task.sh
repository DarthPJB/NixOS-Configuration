#! /bin/sh

echo "Pull the latest version"
git fetch
git pull origin --ff-only

echo "Copy dotfiles into place"
cp -a -r ./dotfiles/.background-image /home/pokej/
cp -a -r ./dotfiles/.config/* /home/pokej/.config/
cp -a -r ./dotfiles/ /home/pokej/ 

echo "Push config into position"
sudo cp -r -a ./config/* /etc/nixos/

echo "Generate new Nix-config"
sudo nixos-rebuild switch
