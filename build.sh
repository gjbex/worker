#!/bin/bash -l

case ${VSC_INSTITUTE_CLUSTER} in
    thinking)
        source switch_to_2015a
        module load foss/2015a
        ;;
    breniac)
        module load foss/2016a
        ;;
esac

./configure CC=mpicc --prefix="${HOME}/tmp/usr"

if [ $? ]
then
    make install
fi
