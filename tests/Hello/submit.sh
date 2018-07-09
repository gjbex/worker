#!/bin/bash

module purge
module load worker

wsub $@ -data data.csv,data2.csv -t 1-100 -batch hello.pbs
