#!/bin/bash -l

make

module load worker 

wsub -batch vec2.pbs -data vec2.csv 

