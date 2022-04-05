#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks-per-node 36
#SBATCH --time=00:05:00
#SBATCH -A wrk

module load R

cd $SLURM_SUBMIT_DIR
export OMP_NUM_THREADS=1

Rscript sum.R ${value1} ${value2}
