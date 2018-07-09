#!/bin/bash -l

./compile.sh
source switch_to_2015a
module load worker/1.6.6-intel-2015a 

wsub -batch fibonacci.pbs -data num.csv -l walltime=00:15:00 -l nodes=1:ppn=20
