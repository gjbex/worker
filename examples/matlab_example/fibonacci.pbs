#!/bin/bash -l
#PBS -l nodes=1:ppn=20
#PBS -l walltime=00:05:00

source switch_to_2015a
module load matlab/R2015b 
cd $PBS_O_WORKDIR

./fibonacci ${num1} 
