#!/bin/bash -l
source switch_to_2015a
module load worker/1.6.6-intel-2015a 

wsub -t 0-20 -batch run-array.pbs
