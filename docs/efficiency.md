Worker is implemented using MPI, so it is not restricted to a single compute node, it scales well to many nodes. However, remember that jobs requesting a large number of nodes typically spend quite some time in the queue.
Worker will be effective when
  * work items, i.e., individual computations, are neither too short, nor too long (i.e., from a few minutes to a few hours); and,
  * when the number of work items is larger than the number of CPUs involved in the job (e.g., more than 30 for 8 CPUs).

Also note that the total execution time of a job consisting of work items
that could be executed using multiple threads will be lower when using
a single thread, provided the number of work items is larger than the
number of cores.

When using a prologue and/or an epilogue, bare in mind that those processes are executed by the master only, while all worker processes are in fact idle. This implies that prologue and epilogues only make sense when they required very little time compared to the actual parallel work to be performed. If execution times of prologue and/or epilogue are considerable, consider submitten jobs with dependencies instead.
