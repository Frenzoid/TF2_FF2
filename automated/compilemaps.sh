echo "--------------------------------------------------------";
echo "| ONLY THE PLAYABLE MAPS SHOULD BE ON tf/maps/ FOLDER! |";
echo "--------------------------------------------------------";


echo "> Removing previous map file tf.txt";
rm $HOME/tf2/tf/addons/sourcemod/configs/mapchooser_extended/maps/tf.txt;

echo "> Compiling maps:";
echo "";

for i in $(ls $HOME/tf2/tf/maps); 
do
 if [[ -f $HOME/tf2/tf/maps/$i && $(cat $HOME/tf2/tf/addons/sourcemod/configs/mapchooser_extended/maps/tf.txt | grep `echo $i | cut -f 1 -d '.'`) != `echo $i | cut -f 1 -d '.'`  ]]; then
  echo $i | cut -f 1 -d '.' >> $HOME/tf2/tf/addons/sourcemod/configs/mapchooser_extended/maps/tf.txt;
  echo $i;
 fi
done;

echo "> Copying tf.txt to tf/cfg/mapcycle...";
cp $HOME/tf2/tf/addons/sourcemod/configs/mapchooser_extended/maps/tf.txt $HOME/tf2/tf/cfg/mapcycle.txt

echo "> Map list recompiled! :D";