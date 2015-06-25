#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "master.h"

int executeScript(char *script, char *name, int verbose);
int execute(char *script);
char *readCmd(FILE *stream, int initLength);
void logStartJob(FILE *logFp, const int rank, const int jobId);
void logEndJob(FILE *logFp, const int rank, const int jobId,
               const int exitStatus);

/* master process logic */
int master(char *prologFile, char *batchFile, char *epilogFile,
           char *logFile, const unsigned int sleepTime, int verbose) {
    if (verbose)
        fprintf(stderr, "### msg: starting master\n");
    /* open the log file, warn on failure */
    FILE *logFp = NULL;
    if (logFile != NULL) {
        logFp = fopen(logFile, "w");
        if (logFp == NULL) {
            fprintf(stderr, "### warning: can't open log file \'%s\'\n",
                    logFile);
        }
    }

    /* do prolog, if any */
    executeScript(prologFile, "prolog", verbose);

    /* get the number of slaves + master */
    int nrProcs;
    MPI_Comm_size(MPI_COMM_WORLD, &nrProcs);
    if (verbose)
        fprintf(stderr, "### msg: %d processes started\n", nrProcs);
    /* jobIds start at 1, so 0 indicates a problem */
    int jobId = 0;

    /* master/slave communication variables */
    MPI_Status status;
    JobInfo jobInfo;
    JobExitInfo jobExitInfo;

    /* open batch file, error on failure */
    char *batch = NULL;
    FILE *dataFp = fopen(batchFile, "r");
    if (dataFp == NULL) {
        fprintf(stderr, "### error: can't open batch file \'%s\'\n",
                batchFile);
        return EXIT_FAILURE;
    }
    /* start reading batch jobs from the batch file */
    while ((batch = readCmd(dataFp, WORK_STR_LENGTH)) != NULL) {
        MPI_Request request;
        int done = 0;
        jobId++;
        if (verbose)
            fprintf(stderr, "### msg: processing job %d\n", jobId);
        /* wait for slave to request work, by receiving either READY or
           DONE */
        MPI_Irecv(&jobExitInfo, 1, jobExitInfoType,
                  MPI_ANY_SOURCE, CMD_TAG, MPI_COMM_WORLD, &request);
        while (!done) {
            MPI_Test(&request, &done, &status);
            usleep(sleepTime);
        }
        int slaveRank = status.MPI_SOURCE;
        /* if jobId was non-zero, log the jobId that this slave completed */
        if (jobExitInfo.jobId != 0 && logFp != NULL)
            logEndJob(logFp, slaveRank, jobExitInfo.jobId,
                      jobExitInfo.exitStatus);
        /* tell the slave that something will have to be computed,
           send the jobId to the slave */
        JobInfo jobInfo = {jobId, strlen(batch) + 1};
        MPI_Send(&jobInfo, 1, jobInfoType, slaveRank, CMD_TAG,
                 MPI_COMM_WORLD);
        MPI_Send(batch, jobInfo.scriptSize, MPI_CHAR, slaveRank, DATA_TAG,
                 MPI_COMM_WORLD);
        if (logFp != NULL)
            logStartJob(logFp, slaveRank, jobId);
        free(batch);
    }
    /* close batch file */
    fclose(dataFp);

    /* wait for slaves to complete, they can either send DONE, if so,
       log, or READY if they never had to do any work; send a TERMINATE
       command to the slave */
    while (nrProcs > 1) {
        MPI_Recv(&jobExitInfo, 1, jobExitInfoType,
                MPI_ANY_SOURCE, CMD_TAG, MPI_COMM_WORLD, &status);
        int slaveRank = status.MPI_SOURCE;
        if (jobExitInfo.jobId != 0 && logFp != NULL)
            logEndJob(logFp, slaveRank, jobExitInfo.jobId,
                      jobExitInfo.exitStatus);
        nrProcs--;
        JobInfo jobInfo = {TERMINATE, 0};
        MPI_Send(&jobInfo, 1, jobInfoType, status.MPI_SOURCE, CMD_TAG,
                 MPI_COMM_WORLD);
    }

    /* close log, if any */
    if (logFp != NULL)
        fclose(logFp);

    /* do epilog, if any */
    executeScript(epilogFile, "epilog", verbose);

    return EXIT_SUCCESS;
}

int executeScript(char *script, char *name, int verbose) {
    if (script != NULL) {
        if (verbose)
            fprintf(stderr, "### msg: starting %s\n", name);
        int exitStatus = execute(script);
        if (exitStatus)
            fprintf(stderr, "### warning: %s exited with status %d\n",
                    name, exitStatus);
        if (verbose)
            fprintf(stderr, "### msg: %s done with status %d\n", name,
                    exitStatus);
        return exitStatus;
    }
    return EXIT_SUCCESS;
}

/*
   Function to check whether a line overflow occurs in an fgets call.
   The string is always delimited by a \0, so no actual overflow occurs,
   but the line may have been truncated, so interpreting the string
   would produce incorrect results.  Function returns 1 if the buffer
   holds the entire line, 0 otherwise.
*/
int lineLenthOkay(char *buff, int length) {
    if (strlen(buff) == length - 1 && buff[strlen(buff)] != '\n')
        return 0;
    return 1;
}

/*
  Function that accepts a file name, opens it and executes it as
  a shell script.  It returns the scripts return code.
*/
int execute(char *script) {
    FILE *fp = fopen(script, "r");
    if (fp == NULL) {
        fprintf(stderr, "### error: can't open file \'%s\'\n", script);
        return EXIT_FAILURE;
    }
    FILE *cp = popen(BASH, "w");
    if (cp == NULL) {
        fprintf(stderr, "### error: can't open command \'%s\'\n", BASH);
        return EXIT_FAILURE;
    }
    char rbuffer[WORK_STR_LENGTH];
    while (fgets(rbuffer, WORK_STR_LENGTH, fp)) {
        if (!lineLenthOkay(rbuffer, WORK_STR_LENGTH)) {
            fprintf(stderr,
                    "### error: line length in script '%s' exceeds %d\n",
                    script, WORK_STR_LENGTH);
            return EXIT_FAILURE;
        }
        fprintf(cp, "%s", rbuffer);
    }
    fclose(fp);
    return pclose(cp);
}

/*
  Function that reads a work item from the data file, it returns NULL
  if none are left to do.  A work item is a text that can be executed
  by bash.  It takes a stream and an initial length as input.  If the
  size of the batch command exceeds initLength, the buffer size is
  incremented with initLength.  The latter should be sufficiently
  large though.  The string in SEPARATOR is used as a terminator for a
  work item.
*/
char *readCmd(FILE *stream, int initLength) {
    int currentLength = initLength;
    char *buffer = (char *) calloc(initLength, sizeof(char));
    buffer[0] = '\0';
    char *rBuffer = (char *) calloc(initLength, sizeof(char));
    /* read input stream line by line, terminate when SEPARATOR is read */
    while (fgets(rBuffer, initLength, stream)) {
        if (!lineLenthOkay(rBuffer, WORK_STR_LENGTH)) {
            fprintf(stderr,
                    "### error: line length in PBS script exceeds %d\n",
                    WORK_STR_LENGTH);
            return NULL;
        }
        if (!strcmp(rBuffer, SEPARATOR))
            break;
        /* if the input is too large, increase batch's size */
        if (strlen(buffer) + strlen(rBuffer) > currentLength) {
            currentLength += initLength;
            char *tmp = (char *) calloc(currentLength, sizeof(char));
            strcat(tmp, buffer);
            free(buffer);
            buffer = tmp;
        }
        strcat(buffer, rBuffer);
    }
    free(rBuffer);
    if (strlen(buffer) > 0) {
        return buffer;
    } else {
        free(buffer);
        return NULL;
    }
}

/* helper function that logs the staart of a job to the log stream */
void logStartJob(FILE *logFp, const int rank, const int jobId) {
    time_t t = time(NULL);
    struct tm *local = localtime(&t);
    char *timeStr = asctime(local);
    timeStr[strlen(timeStr) - 1] = '\0';
    fprintf(logFp, "%d started by %d at %s\n", jobId, rank, timeStr);
    fflush(logFp);
}

/* helper function that logs the completion of a job to the log stream */
void logEndJob(FILE *logFp, const int rank, const int jobId,
               const int exitStatus) {
    time_t t = time(NULL);
    struct tm *local = localtime(&t);
    char *timeStr = asctime(local);
    timeStr[strlen(timeStr) - 1] = '\0';
    if (exitStatus == 0)
        fprintf(logFp, "%d completed by %d at %s\n", jobId, rank, timeStr);
    else
        fprintf(logFp, "%d failed by %d at %s: %d\n", jobId, rank, timeStr,
                exitStatus);
    fflush(logFp);
}
