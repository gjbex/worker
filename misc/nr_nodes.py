#!/usr/bin/env python

from argparse import ArgumentParser
from worker_helper import get_nr_nodes


if __name__ == '__main__':
    arg_parser = ArgumentParser(description='compute number of concurrent '
                                            'work items')
    arg_parser.add_argument('--nr-cores', type=int, default=28,
                            help='number of cores per node')
    arg_parser.add_argument('--walltime', default='1:00:00',
                            help='walltime for the job in '
                                 '[DD:[HH:]]MM:SS')
    arg_parser.add_argument('--nr-items', type=int, default=100,
                            help='number of work items to compute')
    arg_parser.add_argument('--nr-threads', type=int, default=1,
                            help='number of threads per work item')
    arg_parser.add_argument('--exec-time', default='05:00',
                            help='execution time for the job in '
                                 '[DD:[HH:]]MM:SS')
    arg_parser.add_argument('--master', action='store_true',
                            help='-master is used with wsub')
    options = arg_parser.parse_args()
    nr_nodes = get_nr_nodes(options.nr_cores, options.walltime,
                            options.nr_items, options.nr_threads,
                            options.exec_time, options.master)
    print('required nodes = {0:d}'.format(nr_nodes))
