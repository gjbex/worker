#!/bin/bash -l
module load worker

wsub -batch sum_parameterized.pbs -data list.csv 
