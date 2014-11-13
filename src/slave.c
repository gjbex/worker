#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>

#include "slave.h"

/* slave process logic */
int slave(int verbose) {
    /* determine rank */
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    if (verbose)
        fprintf(stderr, "### msg: starting slave %d\n", rank);
    /* variables for master/slave communication */
    MPI_Status status;
    /* tell the master that slave is ready to start work */
    JobExitInfo jobExitInfo = {READY, 0};
    MPI_Send(&jobExitInfo, 1, jobExitInfoType, 0, CMD_TAG, MPI_COMM_WORLD);
    if (verbose)
        fprintf(stderr, "### msg: %d sent ready\n", rank);
    for (;;) {
        JobInfo jobInfo;
        /* wait for an incoming command from the master */
        MPI_Recv(&jobInfo, 1, jobInfoType, 0, CMD_TAG, MPI_COMM_WORLD,
                 &status);
        if (verbose)
            fprintf(stderr, "### msg: %d received jobId %d, length %d\n",
                    rank, jobInfo.jobId, jobInfo.scriptSize);
        /* if command is TERMINATE, all work is done, return successfully */
        if (jobInfo.jobId == TERMINATE) {
            break;
        } else if (jobInfo.jobId > 0) {
            /* work to be done, wait for the jobId */
            char *batch = (char *) calloc(jobInfo.scriptSize, sizeof(char));
            MPI_Recv(batch, jobInfo.scriptSize, MPI_CHAR, 0,
                    DATA_TAG, MPI_COMM_WORLD, &status);
            /* execute batch job, notice that this uses a fork() call */
            FILE *cp = popen(BASH, "w");
            if (cp == NULL) {
                fprintf(stderr, "### error: can't open command '%s'", BASH);
                return EXIT_FAILURE;
            }
            fprintf(cp, "WORKER_RANK=%d\n", rank);
            fprintf(cp, "WORKER_SIZE=%d\n", size);
            fprintf(cp, "%s", batch);
            int exitStatus = pclose(cp);
            free(batch);
            /* notify the master that batch job completed, and more
               work can be sent */
            JobExitInfo jobExitInfo = {jobInfo.jobId,
                                       WEXITSTATUS(exitStatus)};
            MPI_Send(&jobExitInfo, 1, jobExitInfoType, 0, CMD_TAG,
                     MPI_COMM_WORLD);
            if (verbose)
                fprintf(stderr, "### msg: job %d done on slave %d\n",
                        jobInfo.jobId, rank);
        } else {
            fprintf(stderr,
                    "### error: master sent unknown command code %d to slave %d\n",
                    jobInfo.jobId, rank);
            return EXIT_FAILURE;
        }
    }
    return EXIT_SUCCESS;
}
