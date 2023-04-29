#! /bin/sh

echo "Pull the latest version"
#git fetch
#git pull  --ff-only

shopt -s dotglob

echo "Copy dotfiles into place"
 cp -a -r ./dotfiles/.background-image /home/pokej/
cp -a -r ./dotfiles/.config/* /home/pokej/.config/

cp ascetics_bin /home/pokej/ -r

cp winwrap.sh /home/pokej/

#./task.sh
