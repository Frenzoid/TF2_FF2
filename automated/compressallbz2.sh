#!/bin/bash

# For each path inside the first argument passed to the script.
for i in $(find $1); do

# Check f path is a file, and theres no compressed version of the file, and file is not the compressed version.
 if [[ -f $i && ! -f $i.bz2 && $i != *bz2 && $i != $0 ]]; then
   echo "[bzip2]: compressing $i...";
   bzip2 --keep $i;
   echo "[bzip2]: $i compressed.";
   echo "";
 fi

done
