#!/bin/bash -l
module load worker

wsub -batch sum_parameterized.slurm -data list.csv 
