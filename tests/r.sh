#!/bin/bash -l
#PBS -N r-test
#PBS -l walltime=00:05:00

module load R

Rscript script.r $number $stddev
