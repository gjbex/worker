#!/bin/bash -l

./compile.sh

module load worker

wsub -batch fibonacci.slurm -data num.csv 
