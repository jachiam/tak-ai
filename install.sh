git clone https://github.com/torch/distro.git ~/torch --recursive;
cd ~/torch; bash install-deps;
./install.sh;
apt-get -y install love lua5.2 luarocks;
apt-get update && apt-get upgrade -y
luarocks install utf8;
git clone https://github.com/asgardiator/tak-ai.git TakAI --recursive; cd TakAI
git clone https://github.com/vrld/SUIT;
git remote add jach https://github.com/jachiam/tak-ai.git; git merge jach/master
echo "love ." >> 'PLAY_TAKAI.sh';
love .; 