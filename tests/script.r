#!/bin/env Rscript

args <- commandArgs(TRUE)
number <- as.integer(args[1])
std_dev <- as.double(args[2])

mean <- mean(rnorm(n = number, mean = 0.0, sd = std_dev))
result <- c(number, std_dev, mean)
print(result)
