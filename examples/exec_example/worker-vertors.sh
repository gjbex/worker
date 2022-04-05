#!/bin/bash -l
module use /apps/leuven/skylake/2021a/modules/all

#module load worker 
module load worker/1.6.12-foss-2021a

#wsub -batch alphabet.pbs -data alpha.csv
#wsub -batch vec.pbs -data vec.csv 
wsub -batch vec2.pbs -data vec2.csv 
#-time=00:15:00 -n 1
