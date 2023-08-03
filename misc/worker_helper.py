from __future__ import division, print_function
from math import ceil, floor
import sys


def get_nr_concurrent_work_items(nr_cores, nr_threads, nr_nodes,
                                 with_mastter=False):
    '''
    Copmute the number of concurrent work items that require
    nr_threads to run, using nr_nodes with nr_cores each.
    Optionally, if worker's -master option is used, set with
   _mastter to True.

    Parameters:
    -----------
      * nr_cores: number of cores on compute nodes
      * nr_threads: number of threads used to compute
                    a single work item
      * nr_nodes: number of compute nodes to use for the
                  job
      * with_master: True if worker's -master option is
                     used, False by default
    Examples:
    ---------
    >>> get_nr_concurrent_work_items(28, 7, 3)
    11
    >>> get_nr_concurrent_work_items(28, 7, 3, True)
    12
    >>> get_nr_concurrent_work_items(28, 27, 1)
    1
    >>> get_nr_concurrent_work_items(28, 28, 1)
    0
    >>> get_nr_concurrent_work_items(28, 28, 1, True)
    1
    '''
    nr_master_work_items = (nr_cores - 1)//nr_threads
    nr_slave_work_items = nr_cores//nr_threads
    if with_mastter:
        return nr_nodes*nr_slave_work_items
    else:
        return (nr_master_work_items +
                (nr_nodes - 1)*nr_slave_work_items)


def walltime2seconds(walltime):
    '''
    Convert a walltime in format [DD:[HH:]]MM:SS to seconds.
    Parameters:
    -----------
      * walltime: walltime in the format [DD:[HHH:]]MM:SS

    Examples:
    ---------
    >>> walltime2seconds('05:03')
    303
    >>> walltime2seconds('00:48')
    48
    >>> walltime2seconds('03:02:01')
    10921
    >>> walltime2seconds('49:17:48')
    177468
    >>> walltime2seconds('2:13:12:23')
    220343
    '''
    time_strs = walltime.split(':')[::-1]
    return sum(
        period * multiplier
        for period, multiplier in zip(
            map(int, time_strs), [1, 60, 3600, 24 * 3600]
        )
    )


# see derivation.ipynb for details on this function
def get_nr_nodes(nr_cores, walltime, nr_work_items, nr_threads,
                 exec_time, with_master=False):
    '''
    Compute the number of nodes required to execute a given
    number of work items
 
    Parameters
    ----------
      * nr_cores: number of cores on compute nodes
      * walltime: total walltime for the entire job
      * nr_work_items: number of work items to be
                       computed
      * nr_threads: number of threads used to compute
                    a single work item
      * exec_time: execution time of a single work item
                   using the specified number of threads
      * with_master: True if worker's -master option is
                     used, False by default
 
    Examples:
    ---------
    >>> get_nr_nodes(28, '00:16:00', 6, 4, '00:14:00')
    1
    >>> get_nr_nodes(28, '00:30:00', 100, 2, '03:00')
    1
    >>> get_nr_nodes(28, '00:31:00', 1000, 2, '03:00')
    8
    >>> get_nr_nodes(28, '00:30:00', 900, 2, '03:00')
    7
    >>> get_nr_nodes(28, '00:16:00', 8, 4, '00:14:00')
    2
    '''
    if with_master:
        print('### error: master switch computation not implemented yet',
              file=sys.stderr)
        sys.exit(1)
    walltime = walltime2seconds(walltime)
    exec_time = walltime2seconds(exec_time)
    term1 = ceil(nr_work_items/floor(walltime/exec_time))
    term2 = floor((nr_cores - 1)/nr_threads)
    numerator = term1 - term2
    denominator = ceil(nr_cores/nr_threads)
    return 1 + int(ceil(numerator/denominator))
