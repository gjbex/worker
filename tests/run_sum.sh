#!/bin/bash

source /apps/leuven/etc/bash.bashrc

module load perl/5.10.1 gcc/4.6.2

rm -f sum
gcc -O2 -o sum sum.c

export WORKER_DIR="/data/leuven/301/vsc30140/Projects/Worker/"

../bin/wsub -lnodes=2:ppn=8 -batch sum.pbs -data data/sum.txt

