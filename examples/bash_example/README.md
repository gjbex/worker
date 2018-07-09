# `bash_example`

Example of using worker with a bash script.

## What is it?
1. `alphabet.pbs`: PBS script for worker that runs a Bash script
    `alphabet.sh` for each entry in `alpha.csv`.
1. `alphabet.sh`: Bash script that prints the letter converted to
    uppercase, and its number in the alphabet for an input of letter,
    number.
1. `alpha.csv`: data file
1. `worker_alphabet.sh`: Bash script showing how to submit the worker job
    using `wsub`.
