#!/bin/sh

wsub -q qdebug -batch echo.sh -t 1-5 -lnodes=1:ppn=3 -N echos -V
