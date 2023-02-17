#!/bin/bash -l
module load worker

wsub -batch alphabet.slurm -data alpha.csv
