#ifndef MASTER_HDR
#define MASTER_HDR

#include "worker.h"

int master(char *prologFile, char *batchFile, char *epilogFile,
    	   char *logFile, const unsigned int sleepTime, int verbose);

#endif
