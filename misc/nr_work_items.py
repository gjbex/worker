#!/usr/bin/env python

from argparse import ArgumentParser
from worker_helper import get_nr_work_items


if __name__ == '__main__':
    arg_parser = ArgumentParser(description='compute number of '
                                            'concurrent work items')
    arg_parser.add_argument('--nr_cores', type=int, default=28,
                            help='number of cores per node')
    arg_parser.add_argument('--nr_threads', type=int, default=1,
                            help='number of threads per work item')
    arg_parser.add_argument('--nr_nodes', type=int, default=1,
                            help='number of nodes for job')
    arg_parser.add_argument('--master', action='store_true',
                            help='-master is used with wsub')
    options = arg_parser.parse_args()
    nr_work_items = get_nr_work_items(options.nr_cores,
                                      options.nr_threads,
                                      options.nr_nodes,
                                      options.master)
    print('concurrent work items = {0:d}'.format(nr_work_items))
