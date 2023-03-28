#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=36
#SBATCH --time=00:05:00
#SBATCH -A wrk

cd $SLURM_SUBMIT_DIR

alphabet.sh $letter $counter
