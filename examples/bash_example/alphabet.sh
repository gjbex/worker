#!/bin/bash -l

case $2 in 
    [1]|2[1])
        echo  ${1^^} "is the" $2"st letter of the alphabet." ;;
    [2]|2[2])
        echo  ${1^^} "is the" $2"nd letter of the alphabet." ;;
    [3]|2[3])
        echo  ${1^^} "is the" $2"rd letter of the alphabet." ;;
    *)
    echo  ${1^^} "is the" $2"th letter of the alphabet." ;;
esac
