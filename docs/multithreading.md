If a work item uses threading, the execution of a `worker` job is very
similar to that of a hybrid MPI/OpenMP application, and in compbination
with CPU sets, similar measures should be taken to ensure efficient
execution.  `worker` supports this through the `-threaded` flag.
For example, assume a compute node has 20 cores, and a work item runs
efficiently usinng 4 threads, then the following resource specification
would be appropriate:
```
wsub  -lnodes=4:ppn=5  -threaded  ...
```
`worker` ensures that all cores are in the CPU set for the job, but will
not compute more than 5 work items on a node, so that each work item
can use 4 cores.

In order to allow interoperability with tools such as numactl or other
thread-pinning software, two variables are made available to job scripts:
`WORKER_RANK` and `WORKER_SIZE`.  These represent the rank of the slave
in the MPI communicator and the latter's size.  This allows to compute
the placements of the processes started in work items with respect to the
CPU set of the node they are running on.  This can be useful to control
the number of threads used by individual work items.
