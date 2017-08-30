worker
======

[![DOI](https://www.zenodo.org/badge/DOI/10.5281/zenodo.61159.svg)](https://doi.org/10.5281/zenodo.61159)

What is it?
-----------
The Worker framework has been developed to meet specific use cases: many small jobs determined by parameter variations; the scheduler's task is easier when it does not have to deal with too many jobs.

Such use cases often have a common root: the user wants to run a program with a large number of parameter settings, and the program does not allow for aggregation, i.e., it has to be run once for each instance of the parameter values. However, Worker's scope is wider: it can be used for any scenario that can be reduced to a MapReduce approach.

This how-to shows you how to use the Worker framework.  However, for full documentation, please check: http://worker.readthedocs.org/en/latest/

Prerequisites
-------------
A (sequential) job you have to run many times for various parameter values. We will use a non-existent program cfd_test by way of running example.

Step by step
------------
We will consider the following use cases already mentioned above:

parameter variations, i.e., many small jobs determined by a specific parameter set;
job arrays, i.e., each individual job got a unique numeric identifier.
Parameter variations
Suppose the program the user wishes to run is 'cfd_test' (this program does not exist, it is just an example) that takes three parameters, a temperature, a pressure and a volume. A typical call of the program looks like:
```
cfd_test -t 20 -p 1.05 -v 4.3
```
The program will write its results to standard output. A PBS script (say run.pbs) that would run this as a job would then look like:
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=1
#PBS -l walltime=00:15:00
cd $PBS_O_WORKDIR
cfd_test -t 20  -p 1.05  -v 4.3
```
When submitting this job, the calculation is performed or this particular instance of the parameters, i.e., temperature = 20, pressure = 1.05, and volume = 4.3. To submit the job, the user would use:
```
$ qsub run.pbs
```
However, the user wants to run this program for many parameter instances, e.g., he wants to run the program on 100 instances of temperature, pressure and volume. To this end, the PBS file can be modified as follows:
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=8
#PBS -l walltime=04:00:00
cd $PBS_O_WORKDIR
cfd_test -t $temperature  -p $pressure  -v $volume
```
Note that
  * the parameter values 20, 1.05, 4.3 have been replaced by variables $temperature, $pressure and $volume respectively;
  * the number of processors per node has been increased to 8 (i.e., ppn=1 is replaced by ppn=8); and
  * the walltime has been increased to 4 hours (i.e., walltime=00:15:00 is replaced by walltime=04:00:00).

The walltime is calculated as follows: one calculation takes 15 minutes, so 100 calculations take 1,500 minutes on one CPU. However, this job will use 7 CPUs (1 is reserved for delegating work), so the 100 calculations will be done in 1,500/7 = 215 minutes, i.e., 4 hours to be on the safe side. Note that starting from version 1.3, a dedicated CPU is no longer required for delegating work. This implies that in the previous example, the 100 calculations would be completed in 1,500/8 = 188 minutes.

The 100 parameter instances can be stored in a comma separated value file (CSV) that can be generated using a spreadsheet program such as Microsoft Excel, or just by hand using any text editor (do not use a word processor such as Microsoft Word). The first few lines of the file data.txt would look like:
```
temperature,pressure,volume
20,1.05,4.3
21,1.05,4.3
20,1.15,4.3
21,1.25,4.3
...
```
It has to contain the names of the variables on the first line, followed by 100 parameter instances in the current example. Items on a line are separated by commas.

The job can now be submitted as follows:
```
$ module load worker
$ wsub -batch run.pbs -data data.txt
```
Note that the PBS file is the value of the -batch option . The cfd_test program will now be run for all 100 parameter instances — 7 concurrently — until all computations are done. A computation for such a parameter instance is called a work item in Worker parlance.

Job arrays
----------
In olden times when the cluster was young and Moab was not used as a schedular some users developed the habit of using job arrays. The latter is an experimantal torque feature not supported by Moab and hence can no longer be used.

To support those users who used the feature and since it offers a convenient workflow, worker implements job arrays in its own way.

A typical PBS script run.pbs for use with job arrays would look like this:
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=1
#PBS -l walltime=00:15:00
cd $PBS_O_WORKDIR
INPUT_FILE="input_${PBS_ARRAYID}.dat"
OUTPUT_FILE="output_${PBS_ARRAYID}.dat"
word_count -input ${INPUT_FILE}  -output ${OUTPUT_FILE}
```
As in the previous section, the word_count program does not exist. Input for the program is stored in files with names such as ```input_1.dat```, ```input_2.dat```, ..., ```input_100.dat``` that the user produced by whatever means, and the corresponding output computed by word_count is written to ```output_1.dat```, ```output_2.dat```, ..., ```output_100.dat```. (Here we assume that the non-existent word_count program takes options -input and -output.)

The job would be submitted using:
```
$ qsub -t 1-100 run.pbs
```
The effect was that rather than 1 job, the user would actually submit 100 jobs to the queue system (since this puts quite a burden on the scheduler, this is precisely why the scheduler doesn't support job arrays).

Using worker, a feature akin to job arrays can be used with minimal modifications to the PBS script:
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=8
#PBS -l walltime=04:00:00
cd $PBS_O_WORKDIR
INPUT_FILE="input_${PBS_ARRAYID}.dat"
OUTPUT_FILE="output_${PBS_ARRAYID}.dat"
word_count -input ${INPUT_FILE}  -output ${OUTPUT_FILE}
```
Note that
  * the number of CPUs is increased to 8 (ppn=1 is replaced by ppn=8); and
  * the walltime has been modified (walltime=00:15:00 is replaced by walltime=04:00:00).

The walltime is calculated as follows: one calculation takes 15 minutes, so 100 calculation take 1,500 minutes on one CPU. However, this job will use 7 CPUs (1 is reserved for delegating work), so the 100 calculations will be done in 1,500/7 = 215 minutes, i.e., 4 hours to be on the safe side.  Note that starting from version 1.3, a dedicated core for delegating work, so in the previous example, the 100 calculations would be done in 1,500/8 = 188 minutes.

The job is now submitted as follows:
```
$ module load worker
$ wsub -t 1-100  -batch run.pbs
```
The word_count program will now be run for all 100 input files — 7 concurrently — until all computations are done. Again, a computation for an individual input file, or, equivalently, an array id, is called a work item in Worker speak. Note that in constrast to torque job arrays, a worker job array submits a single job.

MapReduce: prologue and epilogue
--------------------------------
Often, an embarrassingly parallel computation can be abstracted to three simple steps:

a preparation phase in which the data is split up into smaller, more manageable chuncks;
on these chuncks, the same algorithm is applied independently (these are the work items); and
the results of the computations on those chuncks are aggregated into, e.g., a statistical description of some sort.
The Worker framework directly supports this scenario by using a prologue and an epilogue. The former is executed just once before work is started on the work items, the latter is executed just once after the work on all work items has finished. Technically, the prologue and epilogue are executed by the master, i.e., the process that is responsible for dispatching work and logging progress.

Suppose that 'split-data.sh' is a script that prepares the data by splitting it into 100 chuncks, and 'distr.sh' aggregates the data, then one can submit a MapReduce style job as follows:
```
$ wsub -prolog split-data.sh  -batch run.pbs  -epilog distr.sh -t 1-100
```
Note that the time taken for executing the prologue and the epilogue should be added to the job's total walltime.

Some notes on using Worker efficiently
--------------------------------------
Worker is implemented using MPI, so it is not restricted to a single compute node, it scales well to many nodes. However, remember that jobs requesting a large number of nodes typically spend quite some time in the queue.
Worker will be effective when
  * work items, i.e., individual computations, are neither too short, nor too long (i.e., from a few minutes to a few hours); and,
  * when the number of work items is larger than the number of CPUs involved in the job (e.g., more than 30 for 8 CPUs).

Also note that the total execution time of a job consisting of work items
that could be executed using multiple threads will be lower when using
a single thread, provided the number of work items is larger than the
number of cores.

Monitoring a worker job
-----------------------
Since a Worker job will typically run for several hours, it may be reassuring to monitor its progress. Worker keeps a log of its activity in the directory where the job was submitted. The log's name is derived from the job's name and the job's ID, i.e., it has the form <jobname>.log<jobid>. For the running example, this could be 'run.pbs.log445948', assuming the job's ID is 445948. To keep an eye on the progress, one can use:
```
$ tail -f run.pbs.log445948
```
Alternatively, a Worker command that summarizes a log file can be used:
```
$ watch -n 60 wsummarize run.pbs.log445948
```
This will summarize the log file every 60 seconds.

Time limits for work items
--------------------------
Sometimes, the execution of a work item takes long than expected, or worse, some work items get stuck in an infinite loop. This situation is unfortunate, since it implies that work items that could successfully are not even started. Again, a simple and yet versatile solution is offered by the Worker framework. If we want to limit the execution of each work item to at most 20 minutes, this can be accomplished by modifying the script of the running example.
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=8
#PBS -l walltime=04:00:00
module load timedrun
cd $PBS_O_WORKDIR
timedrun -t 00:20:00 cfd_test -t $temperature  -p $pressure  -v $volume
```
Note that it is trivial to set individual time constraints for work items by introducing a parameter, and including the values of the latter in the CSV file, along with those for the temperature, pressure and volume.

Also note that 'timedrun' is in fact offered in a module of its own, so it can be used outside the Worker framework as well.

Resuming a Worker job
---------------------
Unfortunately, it is not always easy to estimate the walltime for a job, and consequently, sometimes the latter is underestimated. When using the Worker framework, this implies that not all work items will have been processed. Worker makes it very easy to resume such a job without having to figure out which work items did complete successfully, and which remain to be computed. Suppose the job that did not complete all its work items had ID '445948'.
```
$ wresume -jobid 445948
```
This will submit a new job that will start to work on the work items that were not done yet. Note that it is possible to change almost all job parameters when resuming, specifically the requested resources such as the number of cores and the walltime.
```
$ wresume -l walltime=1:30:00 -jobid 445948
```
Work items may fail to complete successfully for a variety of reasons, e.g., a data file that is missing, a (minor) programming error, etc. Upon resuming a job, the work items that failed are considered to be done, so resuming a job will only execute work items that did not terminate either successfully, or reporting a failure. It is also possible to retry work items that failed (preferably after the glitch why they failed was fixed).
```
$ wresume -jobid 445948 -retry
```
By default, a job's prologue is not executed when it is resumed, while its epilogue is. 'wresume' has options to modify this default behavior.

Multithreaded work items
------------------------
If a work item uses threading, the execution of a `worker` job is very
similar to that of a hybrid MPI/OpenMP application, and in compbination
with CPU sets, similar measures should be taken to ensure efficient
execution.  `worker` supports this through the `-threaded` option.
For example, assume a compute node has 20 cores, and a work item runs
efficiently using 4 threads, then the following resource specification
would be appropriate:
```
wsub  -lnodes=4:ppn=20  -threaded 4  ...
```
`worker` ensures that all cores are in the CPU set for the job, and will
use 4 cores to compute a work item.

In order to allow interoperability with tools such as numactl or other
thread-pinning software, two variables are made available to job scripts:
`WORKER_RANK` and `WORKER_SIZE`.  These represent the rank of the slave
in the MPI communicator and the latter's size.  This allows to compute
the placements of the processes started in work items with respect to the
CPU set of the node they are running on.  This can be useful to control
the number of threads used by individual work items.

Further information
-------------------
This how-to introduces only Worker's basic features. The wsub command has some usage information that is printed when the -help option is specified:
```
### usage: wsub  -batch <batch-file>          \\
#                [-data <data-files>]         \\
#                [-prolog <prolog-file>]      \\
#                [-epilog <epilog-file>]      \\
#                [-log <log-file>]            \\
#                [-mpiverbose]                \\
#                [-threaded <n>]              \\
#                [-dryrun] [-verbose]         \\
#                [-quiet] [-help]             \\
#                [-t <array-req>]             \\
#                [<pbs-qsub-options>]
#
#   -batch <batch-file>   : batch file template, containing variables to be
#                           replaced with data from the data file(s) or the
#                           PBS array request option
#   -data <data-files>    : comma-separated list of data files (default CSV
#                           files) used to provide the data for the work
#                           items
#   -prolog <prolog-file> : prolog script to be executed before any of the
#                           work items are executed
#   -epilog <epilog-file> : epilog script to be executed after all the work
#                           items are executed
#   -mpiverbose           : pass verbose flag to the underlying MPI program
#   -verbose              : feedback information is written to standard error
#   -dryrun               : run without actually submitting the job, useful
#   -quiet                : don't show information
#   -help                 : print this help message
#   -threaded <n>         : indicates that work items are multithreaded,
#                           ensures that CPU sets will have all cores,
#                           regardless of ppn, hence each work item will
#                           have <total node cores>/ppn cores for its
#                           threads
#   -t <array-req>        : qsub's PBS array request options, e.g., 1-10
#   <pbs-qsub-options>    : options passed on to the queue submission
#                           command
```

Troubleshooting
---------------
The most common problem with the `worker` framework is that it doesn't
seem to work at all, showing messages in the error file about module
failing to work.  The cause is trivial, and easy to remedy.

Like any PBS script, a worker PBS file has to be in UNIX format!

If you edited a PBS script on your desktop, or something went wrong
during sftp/scp, the PBS file may end up in DOS/Windows format, i.e.,
it has the wrong line endings.  The PBS/torque queue system can not
deal with that, so you will have to convert the file, e.g., for
file `run.pbs`:
```
$ dos2unix run.pbs
```

Requirements
------------

The software is best installed using the Intel compiler suite, and for
multithreaded workloads to run efficiently, Intel MPI 5.x.


Changes
-------
Changes in version 1.6.4
  * improved "packaging" for distribution
  * bug fix in wresume

Changed in version 1.6.3
  * fixed bug that prevented proper execution of multi-threaded work items

Changed in version 1.6.2
  * fixed reference in documentation so that a page was missing

Changed in version 1.6.1
  * bug fix for absolute paths of prologue/epilogue files

New in version 1.6.0
  * wreduce: a more generic result aggregation function where one can
    any reductor (think wcat, but with a user-defined operator)
  * work item start is now also logged
  * worker ID is logged for all events
  * wload: provides load balancing information to analyse job efficiency
  * user access to MPI_Test sleep time (for power users only)
   
Changed in version 1.5.2
  * increased WORK_STR_LENGTH from 4 kb to 1 Mb

New in version 1.5.1
  * PBS scripts can use `WORKER_RANK` and `WORKER_SIZE` for process binding
  
New in version 1.5.0
  * Support for multithreaded work items

Development
-----------
This application is developed by Geert Jan Bex, Hasselt
University/Leuven University (geertjan.bex@uhasselt.be).  Although the
code is publicly available on GitHub, it is nevertheless an internal
tool, so no support under any form is guaranteed, although it may
be provided.
