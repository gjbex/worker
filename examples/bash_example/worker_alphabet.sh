#!/bin/bash -l
module load worker

wsub -batch alphabet.pbs -data alpha.csv
