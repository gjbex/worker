#!/bin/bash -l

source switch_to_2015a
module load intel/2015a

./configure CC=mpiicc --prefix="${HOME}/tmp/usr"

if [ $? ]
then
    make install
fi
