# `sas_example`

Example of using worker with a SAS script.

## What is it?
1. `sasw.slurm`: SLURM script for worker that runs a SAS script
    `sasjobw` for each entry in `score.csv`.
1. `sasjobw`: SAS script that computes the sum of scores students obtained
    on three exams.
1. `score.csv`: data file
1. `worker_sas.sh`: Bash script showing how to submit the worker job
    using `wsub`.
