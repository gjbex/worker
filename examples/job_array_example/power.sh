#!/bin/bash -l

powerfactor=$(cat $1)
echo powerfactor $powerfactor
powerbase=2
echo powerbase $powerbase
power=$[$powerbase**$powerfactor]
echo 2 raised to the power $powerfactor is $power > $2
