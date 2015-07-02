Since a Worker job will typically run for several hours, it may be reassuring to monitor its progress. Worker keeps a log of its activity in the directory where the job was submitted. The log's name is derived from the job's name and the job's ID, i.e., it has the form <jobname>.log<jobid>. For the running example, this could be `run.pbs.log445948`, assuming the job's ID is 445948. To keep an eye on the progress, one can use:
```
$ tail -f run.pbs.log445948
```
Alternatively, a Worker command that summarizes a log file can be used:
```
$ watch -n 60 wsummarize run.pbs.log445948
```
This will summarize the log file every 60 seconds.

For more detailed analysis of perfornmance issues, the `wload` command can be used.  It will analyze a log file, and output a summary by default.  The latter will provide statistics on the work items (total number, average, minimum and maximum compute time), and the workers (total number, average compute time and average work items computed.
However, more detailed in formation is available by specifying the `-workitems` command line option.  This will list the compute time for each individual work item, the worker it was processed by, and the exit status.
Alternatively, the `-workers` option will list the total execution time and work items processed by each individual worker, which is useful for a load balance analysis.
For example,
```
$ wload -workers run.pbs.log445948
```
would provide worker statistics.
