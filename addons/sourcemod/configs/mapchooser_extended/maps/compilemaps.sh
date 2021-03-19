echo "--------------------------------------------------------";
echo "| ONLY THE PLAYABLE MAPS SHOULD BE ON tf/maps/ FOLDER! |";
echo "--------------------------------------------------------";


echo "> Removing previous map file tf.txt";
rm /home/frenzoid/TF2_FF2/tf/addons/sourcemod/configs/mapchooser_extended/maps/tf.txt;

echo "> Compiling maps:";
echo "";

for i in $(ls /home/frenzoid/TF2_FF2/tf/maps); 
do
 if [[ -f /home/frenzoid/TF2_FF2/tf/maps/$i && $(cat /home/frenzoid/TF2_FF2/tf/addons/sourcemod/configs/mapchooser_extended/maps/tf.txt | grep `echo $i | cut -f 1 -d '.'`) != `echo $i | cut -f 1 -d '.'`   ]]; then
  echo $i | cut -f 1 -d '.' >> /home/frenzoid/TF2_FF2/tf/addons/sourcemod/configs/mapchooser_extended/maps/tf.txt;
  echo $i;
 fi
done;

# echo "> Copying tf.txt to tf/cfg/mapcycle...";
# cp /home/frenzoid/TF2_FF2/tf/addons/sourcemod/configs/mapchooser_extended/maps/tf.txt /home/frenzoid/TF2_FF2/tf/cfg/mapcycle.txt

echo "> Map list recompiled! :D";