#!/bin/bash -l

make

module load worker 

wsub -batch vec2.slurm -data vec2.csv 
