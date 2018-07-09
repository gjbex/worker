# `job_array_example`

Example of using worker's job array feature with a bash script.

## What is it?
1. ``run-array.pbs`: PBS script for worker that runs a Bash script
    `power.sh` for each value specified by the `-t` option upon job
    submission.
1. `power.sh`: Bash script that reads the content of a file (single
    number) and raise 2 to that number, printing the result.
1. `input0.dat`...`input19.dat`: data files
1. `worker-array-power.sh`: Bash script showing how to submit the worker job
    using `wsub` with the `-t` options.
