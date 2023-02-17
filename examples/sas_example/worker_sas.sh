#!/bin/bash -l

module load worker

wsub -batch sasw.slurm -data score.csv 
