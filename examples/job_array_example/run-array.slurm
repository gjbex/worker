#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks-per-node 36
#SBATCH --time=00:05:00
#SBATCH -A wrk

cd $SLURM_SUBMIT_DIR

INPUT_FILE="input${PBS_ARRAYID}.dat"
OUTPUT_FILE="output${PBS_ARRAYID}.dat"
power.sh ${INPUT_FILE} ${OUTPUT_FILE}
