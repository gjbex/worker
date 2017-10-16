args <- commandArgs(TRUE) 
value1 <- as.integer(args[1]) 
value2 <- as.integer(args[2]) 
sumv=value1+value2

cat("Calculating sum:\n")
result <- sprintf(" %i + %i = %i \n",
                     value1, value2, sumv  )

cat(result) 
