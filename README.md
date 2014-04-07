worker
======

What is it?
-----------
The worker framework is intended to support embarrassingly parallel
computations (typically parameter explorations) on HPC clusters.

The approach is master/slave.  The master provides work to the slaves,
i.e., a particular instance of the parameters, who report back to the
master as soon as their task is completed.  The master continues to
send work items until all work is done.

The user simply provides a parameterized job script that describes how
to compute a single work item, as well as a CSV file that defines all
work items, one per row.

The framework provides some facilities to ease the user's life, e.g.,
a command to monitor the progress of the work, to resume a job that was
interrupted from the point it had reached, to aggregate results for work
items if those were saved to individual files.

Development
-----------
This application is developed by Geert Jan Bex, Hasselt University/KU Leuven (geertjan.bex@uhasselt.be).  Although the code is publicly available
on itHub, it is nevertheless an internal tool, so no support under any
from is guaranteed, although it may be provided.

