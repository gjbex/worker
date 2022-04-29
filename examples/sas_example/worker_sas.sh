#!/bin/bash -l

module load worker

wsub -batch sasw.pbs -data score.csv 
