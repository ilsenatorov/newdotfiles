#!/bin/sh
for i in */; do
	bas=$(basename $i)
	echo "Linking $bas"
	rm -r ~/.config/$bas
	ln -s ~/dotfiles/$bas ~/.config/$bas
done
