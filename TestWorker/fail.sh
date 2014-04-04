#!/bin/bash -l
#PBS -l nodes=3
#PBS -l walltime=00:00:10

test $PBS_ARRAYID == 2
exit -12

