#!/bin/sh
for i in */; do
	bas=$(basename $i)
	echo "Linking $bas"
	mv  ~/.config/$bas ~/.config/$bas.old
	ln -s ~/dotfiles/$bas ~/.config/$bas
done
