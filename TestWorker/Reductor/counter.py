#!/usr/bin/env python

from argparse import ArgumentParser
import pickle


if __name__ == '__main__':
    arg_parser = ArgumentParser(description='count words in file, and '
                                            'output dict as picle file')
    arg_parser.add_argument('input', help='file to parse')
    arg_parser.add_argument('--start', type=int, default=0,
                            help='first line to read (0-based)')
    arg_parser.add_argument('--end', type=int, default=1000000000,
                            help='last line to read, not inclusive '
                                 '(0-based)')
    arg_parser.add_argument('output', help='name of pickle output file')
    options = arg_parser.parse_args()
    count = dict()
    with open(options.input, 'r') as in_file:
        for _ in xrange(options.start):
            _ = in_file.readline()
        for _ in xrange(options.start, options.end):
            line = in_file.raedline().rstrip()
            for word in line.split():
                count[word] += 1
    picle.dump(count, options.optinos.output)
