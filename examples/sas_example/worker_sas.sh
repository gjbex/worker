#!/bin/bash -l

module load worker

wsub -batch sas.slurm -data score.csv 
