# Usage scenarios

## Job arrays

The user prepares a PBS script that calls a program, e.g.,
`cfd_solver`, that takes an parameter file specified on the
command line.  The PBS file `cfd.pbs` could look something like:
```
#!/bin/bash -l
#PBS -N cfd_solver
#PBS -l nodes=1
#PBS -l walltime=00:05:00

cd $PBS_O_WORKDIR

cfd_solver -p parameters-$PBS_ARRAYID.cfg > result-$PBS_ARRAYID.dat
```

For 100 parameter instances called `parameters-1.cfg`,...,
`parameters-100.cfg`, the following obsolete `qsub` command would run
`cfd_solver` on each of those 100 parameter files, saving the results of
each run in `result-1.dat`, ..., `result-100.dat` respectively:
```
qsub  -t 1-100  cfd.pbs
```

Each job in the job array was assigned a unique number between 1 and
100 that is accessible via the shell variable `$PBS_ARRAYID`.

Given that Moab does not support job arrays, Worker can now handle
this setup transparently.

```
$ module load worker
$ wsub  -t 1-100  -batch cfd.pbs  -l nodes=8
```

Notice that you have to request the number of nodes you want
`worker` to use, multiples of 8 will be most efficient.  In
this case, 7 nodes will do the work, so the speedup due to
parallellization will be approximately 7.

The `wsub` command takes all options that were valid for
torque's `qsub`, notably the features and resources requested
via the `-l` option.


## Parameter variations

A fairly common usage scenario is similar to the previous one,
except that the parameter instances are to be provided on the command
line, rather than in a configuration file.  By way of example,
consider the parameters in the comma separated value (CSV) format in
the file `data.csv` below:

```
temperature,pressure,volume
293.0,1.0e6,1.0
294.0,1.0e6,1.0
295.0,1.0e6,1.0
296.0,1.0e6,1.0
...
```

These values can be supplied a program via the command line, e.g.,
`simulate  -t 293.0  -p 1.0e6  -v 1.0`. Now the user want to run
`simulate` for each parameter set in `data.csv<`.  First,
the following PBS script `simulate.pbs` should be created:

```
#!/bin/bash -l
# PBS -N simulate

simulate  -t $temperature  -p $pressure  -v $volume
```

Note that the variables `$temperature`, `$pressure`, and `$volume`
correspond to the column names in `data.csv`

The job can now be run using:
```
$ module load worker
$ wsub  -data data.csv  -batch simulate.pbs  -l nodes=8
```

Notice that you have to request the number of nodes you want
worker to use, multiples of 8 will be most efficient.  In
this case, 7 nodes will do the work, so the speedup due to
parallellization will be approximately 7.

The `wsub` command takes all options that were valid for
torque's `qsub`, notably the features and resources requested
via the `-l` option.

## MapReduce

Using `wsub`'s `-prolog` and `-epilog` options, it is straightforward
to implement MapReduce scenarios.  The shell scripts passed through
`-prolog` and `-epilog` are processed by the worker master before any
work is started, and after all work has been completed, respectively.
Hence the prolog shell script can be used to split the data in chuncks
that can be handled by the slaves in parallel, while the epilog script
can collect the results and postprocess them.
