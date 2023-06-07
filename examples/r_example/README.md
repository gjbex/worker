# `r_example`

Example of using worker with an R script.

## What is it?
1. `sum_parameterized.slurm`: SLURM script for worker that runs an R script
    `sum.R` for each entry in `list.csv`.
1. `sum.R`: R script that sums the values of its two arguments, and prints
    the result.
1. `list.csv`: data file
1. `worker_sum.sh`: Bash script showing how to submit the worker job
    using `wsub`.
