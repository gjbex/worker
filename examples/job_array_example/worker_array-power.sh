#!/bin/bash -l
module load worker

wsub -t 0-20 -batch run-array.slurm
