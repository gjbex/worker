In some settings, each the execution of each work item results in an individual file, but as a post-processing step, these files should be aggregated into a single one.  Since this scenario is fairly common, worker supports it through two command, `wcat` and `wredcue`.

Typically, the names of the files are based on one or more variables that are present in the data file.  By way of example, we will assume three variables `temperature`, `pressure`, and `volume` in a CSV file `data.csv`.  The PBS script fragment below illustrates how the files are created.
```
simulate -t $temperature -p $pressure -v $volume \
    > output-$temperature-$pressure-$volume.txt
```

For the running example, this would result in a set of files such as:
```
output-293.0-1.0e6-1.0.txt
output-294.0-1.0e6-1.0.txt
output-295.0-1.0e6-1.0.txt
output-296.0-1.0e6-1.0.txt
```

The `wcat` command can now be used to conveniently concatenate these files, based on the data file that was used to define the work items, and the pattern that describes the file names.
```
$ wcat  -pattern 'output-[%temperature%]-[%pressure%]-[%volume%].txt' \
        -data data.csv  -output output.txt
```
This command will concatenate the individual files into `output.txt`.  `wcat` has several options such as `-skep_fiter <n>` that will skip the first `n` lines of each file so that, .e.g., headers are not repeated each time.  By default, blank lines at the end of files are skipped, though this can be avoided by using the `-keep_blank` option.

To support scenarios where the reduction of output files is complex, or the output is not text, `wreduce` offers assistance.  It works similar to `wcat` but additionally a reductor script has to be provided.
The latter takes two parameters, the name of the file that will contain the aggregated output, and the other the file name that contains data to be added to the former.
The following reductor script, `reductor.sh` mimics the behaviour of `wcat`
```
#!/bin/bash
cat $2 >> $1
```
The reduction would be done using `wreduce` as follows:
```
$ wreduce  -pattern 'output-[%temperature%]-[%pressure%]-[%volume%].txt' \
           -data data.csv  -reductor reductor.sh  -output output.txt
```
This command can be used to deal with R data files, provided the reductor script contains a call to an R script that adds the individual data to the global data structure.
