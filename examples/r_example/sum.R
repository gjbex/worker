args <- commandArgs(TRUE) 
value1 <- as.integer(args[1]) 
value2 <- as.integer(args[2]) 
sumv=value1+value2

cat("Calculating sum:\n")
result <- sprintf(" %i + %i = %i \n",
                     value1, value2, sumv  )

cat(result) 

shost<-Sys.getenv("HOSTNAME")

cat(shost, file=paste(toString(value1, width=2),".dat",sep=""),sep="\n")
cat("Calculating sum: ", file=paste(toString(value1, width=2),".dat",sep=""),sep="\n",append=TRUE)
cat(result, file=paste(toString(value1, width=2),".dat",sep=""),sep="\n",append=TRUE)

