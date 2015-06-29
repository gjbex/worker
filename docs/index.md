# Introduction and motivation

The Worker framework has been developed to meet two specific use
cases:

* job arrays: replace the <tt>-t</tt> for array requests; this was an
    experimental feature provided by the torque queue system, but it is
    not supported by Moab, the current scheduler. </li>
* many small jobs determined by parameter variations; the scheduler's
    task is easier when it does not have to deal with too many jobs.

Both use cases often have a common root: the user wants to run a
program with a large number of parameter settings, and the program
does not allow for aggregation, i.e., it has to be run once for each
instance of the parameter values.

However, Worker's scope is wider: it can be used for any scenario
that can be reduced to a http://en.wikipedia.org/wiki/MapReduce">MapReduce
approach.
