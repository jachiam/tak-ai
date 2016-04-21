#!/bin/sh
git clone https://github.com/asgardiator/tak-ai.git ~/Tak-AI --recursive
git clone https://github.com/torch/distro.git ~/torch --recursive
cd ~/torch; bash install-deps;
./install.sh
source ~/.zshrc
source ~/.bashrc
source ~/.profile