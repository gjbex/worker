#!/bin/bash -l
#PBS -N my-job
#PBS -l walltime=00:05:00
#PBS -lnodes=2

echo $HOME
# PBS_ARRAY_STR is a nice variable, while $PBS_ARRAYIDs are useful
echo $PBS_ARRAYID $HOME
echo "$PBS_ARRAYID"
echo "compute($PBS_ARRAYID)"
echo "$temperature + $pressure"
echo "$delta + $gamma"
echo "rank $WORKER_RANK"
echo "$PBS_O_WORKDIR"


