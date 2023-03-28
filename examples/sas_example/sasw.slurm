#!/bin/bash -l
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=36
#SBATCH --time=00:05:00
#SBATCH -A wrk


module load SAS
cd $SLURM_SUBMIT_DIR

SAS_WORKDIR="sas-tmp-${PBS_JOBID}-${student}"
mkdir ${SAS_WORKDIR}
SAS_LOG="sas-log-${PBS_JOBID}-${student}"
mkdir ${SAS_LOG}

#sas sasjobw -set student $student -set scm $scm -set scb $scb -set scc $scc
sas  -WORK ${SAS_WORKDIR}  -log ${SAS_LOG}  -batch -noterminal -cpucount 1 -set student $student -set scm $scm -set scb $scb -set scc $scc sasjobw

rm -r ${SAS_WORKDIR}
rm -r ${SAS_LOG}
