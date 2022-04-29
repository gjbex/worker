#!/bin/bash -l

./compile.sh

module load worker

wsub -batch fibonacci.pbs -data num.csv 
