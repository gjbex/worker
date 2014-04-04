confdir = $(prefix)/conf
dist_conf_DATA = worker.conf.tmpl

# m4 macro processor
M4 = $(shell which m4)

QSUB_CMD = $(shell which qsub)
SUPPORT_EMAIL = "hpcinfo@kuleuven.be"
UNLOAD_MODULES = openmpi
MPI_MODULE = openmpi/1.6.3_gcc
MPIRUN_CMD = mpirun
MPIRUN_OPTIONS = -mca mpi_warn_on_fork 0

conf_DATA = worker.conf

worker.conf: worker.conf.tmpl
	$(M4) -DQSUB_CMD=$(QSUB_CMD) \
	      -DSUPPORT_EMAIL="$(SUPPORT_EMAIL)" \
	      -DUNLOAD_MODULES="$(UNLOAD_MODULES)" \
	      -DMPI_MODULE="$(MPI_MODULE)" \
	      -DMPIRUN_CMD="$(MPIRUN_CMD)" \
	      -DMPIRUN_OPTIONS="$(MPIRUN_OPTIONS)" \
	      $< > $@

