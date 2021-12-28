cd /home/frenzoid/TF2_FF2/tf/
bash automated/compressallbz2.sh maps
bash automated/compressallbz2.sh materials
bash automated/compressallbz2.sh models
bash automated/compressallbz2.sh sound
git add "models/*.bz2"
git add "materials/*.bz2"
git add "sound/*.bz2"
git add "maps/koth_*.bz2"
git add "maps/arena_*.bz2"
git add "maps/vsh_*.bz2"
git add addons
git add cfg
git add automated
git add README.md
git add nginxconf.txt
git add start_server.sh
git add srcds_run
git add srcds_linux
git add start.sh

git commit -m "Automatic commit. Commit date: $(date)"
