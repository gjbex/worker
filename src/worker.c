/* --------------------------------------------------------------------
  Worker provides a master/slave setup for batch jobs.  A file with
  batch jobs separated by SEPARATOR is provided.  This file is parsed
  by the master, who sends each of the jobs to a slave using MPI for
  communication.

  Note that this program will only work on MPI implementations that
  can handle fork() correctly.  To avoid warnings under OpenMPI, call
  mpirun with '-mca mpi_warn_on_fork 0'.

  --------------------------------------------------------------------- */

#include <mpi.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "worker.h"
#include "master.h"
#include "slave.h"

void printHelp(void);
void initMpiTypes(void);
void freeMpiTypes(void);

/* global verbosity flag, to be set on the command line */
int verbose = 0;
/* global MPI user defined types */
MPI_Datatype jobInfoType, jobExitInfoType;

int main(int argc, char *argv[]) {

    /* deal with command line arguments */
    char *prologFile = NULL;
    char *batchFile = NULL;
    char *epilogFile = NULL;
    char *logFile = NULL;
    char optChar = '\0';
    unsigned int sleepTime = DEFAULT_USLEEP, numThreads = 1;
    int rank, size, exitStatus;

    /* initialize MPI, and get the rank */
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    /* check whether there is at least 1 slave */
    if (size == 1) {
        fprintf(stderr, "### error: at least one slave needed,\n"
                "           modify nodes/ppn\n");
        MPI_Abort(MPI_COMM_WORLD, 1);
    }

    /* handle command line options */
    while ((optChar = getopt(argc, argv, "p:b:e:l:s:t:vh")) != -1) {
        switch (optChar) {
            case 'p':
                prologFile = optarg;
                break;
            case 'b':
                batchFile = optarg;
                break;
            case 'e':
                epilogFile = optarg;
                break;
            case 'l':
                logFile = optarg;
                break;
            case 'v':
                verbose = 1;
                break;
            case 's':
                sleepTime = (unsigned int) atoi(optarg);
                break;
            case 't':
                numThreads = (unsigned int) atoi(optarg);
                break;
            case 'h':
                printHelp();
                return EXIT_SUCCESS;
            default:
                fprintf(stderr, "### error: invalid option \'%c\'\n",
                        optChar);
                printHelp();
                return EXIT_FAILURE;
        }
    }
    if (batchFile == NULL) {
        fprintf(stderr, "### error: no data file specified\n");
        printHelp();
        return EXIT_FAILURE;
    }

    /* communicate command line parameters to other processes */
    MPI_Bcast(&numThreads, 1, MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Bcast(&verbose, 1, MPI_INT, 0, MPI_COMM_WORLD);

    /* initialize types */
    initMpiTypes();

    /* do the actual work, either as master, or as slave */
    if (rank == 0) {
        if (verbose) {
            fprintf(stderr, "### msg: starting master\n");
        }
        exitStatus = master(prologFile, batchFile, epilogFile, logFile,
                            sleepTime, verbose);
        if (verbose) {
            fprintf(stderr, "### msg: master ending\n");
        }
        if (exitStatus != EXIT_SUCCESS)
            if (verbose) {
                fprintf(stderr, "### msg: master exiting with status %d\n", exitStatus);
            }
            MPI_Abort(MPI_COMM_WORLD, 2);
    } else {
        if (verbose) {
            fprintf(stderr, "### msg: starting slave %d\n", rank);
        }
        exitStatus = slave(numThreads, verbose);
        if (verbose) {
            fprintf(stderr, "### msg: slave %d ending with status %d\n", rank, exitStatus);
        }
    }

    /* free up type resources */
    freeMpiTypes();

    /* clean up */
    MPI_Finalize();

    return exitStatus;
}

/* initialize user defined MPI types */
void initMpiTypes(void) {
    MPI_Datatype baseTypes[1];
    int blockCounts[1];
    MPI_Aint offsets[1];
    offsets[0] = 0;
    baseTypes[0] = MPI_INT;
    blockCounts[0] = 2;
    MPI_Type_create_struct(1, blockCounts, offsets, baseTypes, &jobInfoType);
    MPI_Type_commit(&jobInfoType);
    MPI_Type_create_struct(1, blockCounts, offsets, baseTypes, &jobExitInfoType);
    MPI_Type_commit(&jobExitInfoType);
}

void freeMpiTypes(void) {
    MPI_Type_free(&jobInfoType);
    MPI_Type_free(&jobExitInfoType);
}

/* print command line usage information */
void printHelp() {
    fprintf(stderr,
        "### usage: worker [-p <prolog>] -b <batch> [-e <epilog>] \\\n"
        "                  [-l <log>] [-v] [-h]\n"
        "# -p <prolog>  : prolog file, executed by master before slaves\n"
        "#                are started\n"
        "# -b <batch>   : batch file containing the work items to do\n"
        "#                by the slaves\n"
        "# -e <epilog>  : epilog file, executed by master after slaves\n"
        "#                are stopped\n"
        "# -l <log>     : log file, can be monitored for progress,\n"
        "#                if not specified, no logging is done\n"
        "# -s <sleep>   : sleep time for master in MPI_Test loop\n"
        "  -t <threads> : number of threads to use for the work items'\n"
        "# -v           : give verbose feedback\n"
        "# -h           : print this help message\n"
    );
}
