#!/bin/bash -l

case ${VSC_INSTITUTE_CLUSTER} in
    thinking)
        source switch_to_2015a
        module load intel/2015a
        ;;
    breniac)
        module load intel/2016a
        ;;
esac

./configure CC=mpiicc --prefix="${HOME}/tmp/usr"

if [ $? ]
then
    make install
fi
