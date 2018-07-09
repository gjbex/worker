#!/bin/bash -l
source switch_to_2015a
module load worker/1.6.7-intel-2015a 

wsub -batch sum_parameterized.pbs -data list.csv -l walltime=00:15:00 -l nodes=1:ppn=20
