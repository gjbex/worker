New in version 1.6.0

  * `wreduce`: a more generic result aggregation function where one can
    any reductor (think wcat, but with a user-defined operator)
  * work item start is now also logged, worker ID is logged for all events
  * `wload`: provides load balancing information to analyse job efficiency
  * user access to MPI_Test sleep time (for power users only)
  * documentation expanded and made available on the web
   
Changed in version 1.5.2

  * increased WORK_STR_LENGTH from 4 kb to 1 Mb

New in version 1.5.1

  * PBS scripts can use `WORKER_RANK` and `WORKER_SIZE` for process binding
  
New in version 1.5.0

  * Support for multithreaded work items
