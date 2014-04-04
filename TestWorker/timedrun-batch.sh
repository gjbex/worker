#!/bin/bash -l
#PBS -N runtimed
#PBS -l walltime=00:01:00
#PBS -l nodes=2:ppn=2

module load timedrun/1.0

echo $taskID
timedrun -t 10 sleep $sleeptime
