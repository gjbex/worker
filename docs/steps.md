As prerequisites, one should have a (sequential) job that has to be run many times for various parameter values, or on a large number of input files. By way of running example, we will use a non-existent program cfd_test for the former case, and an equally non-existent word_count for the latter case.

We will consider the following use cases already mentioned above:

  * parameter variations, i.e., many small jobs determined by a specific parameter set;
  * job arrays, i.e., each individual job got a unique numeric identifier.

## Parameter variations

Suppose the program the user wishes to run is 'cfd_test' (this program does not exist, it is just an example) that takes three parameters, a temperature, a pressure and a volume. A typical call of the program looks like:
```
cfd_test -t 20 -p 1.05 -v 4.3
```
The program will write its results to standard output. A PBS script (say run.pbs) that would run this as a job would then look like:
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=1
#PBS -l walltime=00:15:00
cd $PBS_O_WORKDIR
cfd_test -t 20  -p 1.05  -v 4.3
```
When submitting this job, the calculation is performed or this particular instance of the parameters, i.e., temperature = 20, pressure = 1.05, and volume = 4.3. To submit the job, the user would use:
```
$ qsub run.pbs
```
However, the user wants to run this program for many parameter instances, e.g., he wants to run the program on 100 instances of temperature, pressure and volume. To this end, the PBS file can be modified as follows:
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=8
#PBS -l walltime=04:00:00
cd $PBS_O_WORKDIR
cfd_test -t $temperature  -p $pressure  -v $volume
```
Note that
  * the parameter values 20, 1.05, 4.3 have been replaced by variables $temperature, $pressure and $volume respectively;
  * the number of processors per node has been increased to 8 (i.e., ppn=1 is replaced by ppn=8); and
  * the walltime has been increased to 4 hours (i.e., walltime=00:15:00 is replaced by walltime=04:00:00).

The walltime is calculated as follows: one calculation takes 15 minutes, so 100 calculations take 1,500 minutes on one CPU. However, this job will use 7 CPUs (1 is reserved for delegating work), so the 100 calculations will be done in 1,500/7 = 215 minutes, i.e., 4 hours to be on the safe side. Note that starting from version 1.3, a dedicated CPU is no longer required for delegating work. This implies that in the previous example, the 100 calculations would be completed in 1,500/8 = 188 minutes.

The 100 parameter instances can be stored in a comma separated value file (CSV) that can be generated using a spreadsheet program such as Microsoft Excel, or just by hand using any text editor (do not use a word processor such as Microsoft Word). The first few lines of the file data.txt would look like:
```
temperature,pressure,volume
20,1.05,4.3
21,1.05,4.3
20,1.15,4.3
21,1.25,4.3
...
```
It has to contain the names of the variables on the first line, followed by 100 parameter instances in the current example. Items on a line are separated by commas.

The job can now be submitted as follows:
```
$ module load worker
$ wsub -batch run.pbs -data data.txt
```
Note that the PBS file is the value of the -batch option . The cfd_test program will now be run for all 100 parameter instances — 7 concurrently — until all computations are done. A computation for such a parameter instance is called a work item in Worker parlance.

## Job arrays

In olden times when the cluster was young and Moab was not used as a schedular some users developed the habit of using job arrays. The latter is an experimantal torque feature not supported by Moab and hence can no longer be used.

To support those users who used the feature and since it offers a convenient workflow, worker implements job arrays in its own way.

A typical PBS script run.pbs for use with job arrays would look like this:
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=1
#PBS -l walltime=00:15:00
cd $PBS_O_WORKDIR
INPUT_FILE="input_${PBS_ARRAYID}.dat"
OUTPUT_FILE="output_${PBS_ARRAYID}.dat"
word_count -input ${INPUT_FILE}  -output ${OUTPUT_FILE}
```
As in the previous section, the word_count program does not exist. Input for the program is stored in files with names such as ```input_1.dat```, ```input_2.dat```, ..., ```input_100.dat``` that the user produced by whatever means, and the corresponding output computed by word_count is written to ```output_1.dat```, ```output_2.dat```, ..., ```output_100.dat```. (Here we assume that the non-existent word_count program takes options -input and -output.)

The job would be submitted using:
```
$ qsub -t 1-100 run.pbs
```
The effect was that rather than 1 job, the user would actually submit 100 jobs to the queue system (since this puts quite a burden on the scheduler, this is precisely why the scheduler doesn't support job arrays).

Using worker, a feature akin to job arrays can be used with minimal modifications to the PBS script:
```
#!/bin/bash -l
#PBS -l nodes=1:ppn=8
#PBS -l walltime=04:00:00
cd $PBS_O_WORKDIR
INPUT_FILE="input_${PBS_ARRAYID}.dat"
OUTPUT_FILE="output_${PBS_ARRAYID}.dat"
word_count -input ${INPUT_FILE}  -output ${OUTPUT_FILE}
```
Note that
  * the number of CPUs is increased to 8 (ppn=1 is replaced by ppn=8); and
  * the walltime has been modified (walltime=00:15:00 is replaced by walltime=04:00:00).

The walltime is calculated as follows: one calculation takes 15 minutes, so 100 calculation take 1,500 minutes on one CPU. However, this job will use 7 CPUs (1 is reserved for delegating work), so the 100 calculations will be done in 1,500/7 = 215 minutes, i.e., 4 hours to be on the safe side.  Note that starting from version 1.3, a dedicated core for delegating work, so in the previous example, the 100 calculations would be done in 1,500/8 = 188 minutes.

The job is now submitted as follows:
```
$ module load worker
$ wsub -t 1-100  -batch run.pbs
```
The word_count program will now be run for all 100 input files — 7 concurrently — until all computations are done. Again, a computation for an individual input file, or, equivalently, an array id, is called a work item in Worker speak. Note that in constrast to torque job arrays, a worker job array submits a single job.
