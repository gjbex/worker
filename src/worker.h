#ifndef WORKER_HDR
#define WORKER_HDR

#include <mpi.h>

/* MPI tags */
#define CMD_TAG 0
#define DATA_TAG 1

/* commands used for communication between master and slaves */
#define TERMINATE 0
#define READY 0

/* structs to convey information on job submission & completion */
typedef struct {
    int jobId, scriptSize;
} JobInfo;
typedef struct {
    int jobId, exitStatus;
} JobExitInfo;
extern MPI_Datatype jobInfoType, jobExitInfoType;

/* initial length of the char array that will hold a batch script */
#define WORK_STR_LENGTH 1048576

/* interpreter to use by the slaves for the batch scripts */
#define BASH "/bin/bash -l"

/* separator for batch file */
#define SEPARATOR "#####--END\n"

#endif
