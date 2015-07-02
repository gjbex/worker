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
