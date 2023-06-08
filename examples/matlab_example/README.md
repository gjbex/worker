# `matlab_example`

Example of using worker with a Matlab script.

## What is it?
1. `fibonacci.slurm`: SLURM script for worker that runs a Matlab script
    `fibonacci.m` for each entry in `num.csv`.
1. `fibonacci.m`: Matlab script that computes the Fibonacci number for the
    given input.
1. `num.csv`: data file
1. `worker_fib.sh`: Bash script showing how to submit the worker job
    using `wsub`.
