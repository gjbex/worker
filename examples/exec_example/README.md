# `exec_example`

Example of using worker with a bash script.

## What is it?
1. `vec2.slurm`: SLURM script for worker that runs an executable file `vectors1.exe`
    for each dimension from `vec2.csv`.
1. `vectors_omp.cpp`: C++ code for creating executable file `vectors1.exe`.
1. `vec2.csv`: data file
1. `Makefile`: recipe for compiling `vectors_omp.cpp` into `vectors1.exe`.
3. `worker-vertors.sh`: Bash script showing how to submit the worker job
    using `wsub`.
