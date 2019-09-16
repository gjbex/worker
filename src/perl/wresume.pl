#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Config::General;
use File::Basename;
use File::Copy;
use File::Temp qw/ tempdir /;
use FindBin;
use Getopt::Long;
use IO::Dir;
use IO::Scalar;
use Template;

sub BEGIN {
    if (exists $ENV{WORKER_DIR} && defined $ENV{WORKER_DIR} &&
            length($ENV{WORKER_DIR}) > 0) {
        unshift(@INC, "$ENV{WORKER_DIR}/lib/perl");
    } else {
        unshift(@INC, "$FindBin::Bin/../lib/perl");
    }
}

use Worker::CsvProvider;
use Worker::DataProvider;
use Worker::Preprocessor;
use Worker::ExecutedTasksFilter;
use Worker::LogParser;
use Worker::RunfileParser;
use Worker::TaskfileParser;
use Worker::Utils qw( parse_hdr check_file msg compute_file_extension
		      quote_options hash_options );
use Pbs::Parser;

# directory containing the Worker software
my $worker_dir = undef;
if (exists $ENV{WORKER_DIR} && defined $ENV{WORKER_DIR} &&
        length($ENV{WORKER_DIR}) > 0) {
    $worker_dir = "$ENV{WORKER_DIR}";
} else {
    $worker_dir = "$FindBin::Bin/..";
}
$worker_dir .= '/' unless length($worker_dir) == 0 || $worker_dir =~ m|/$|;
check_file($worker_dir, 'worker directory', 1, 1);

my $config_file = "${worker_dir}/conf/worker.conf";
check_file($config_file, 'configuration file', 1);
msg("reading config file '$config_file'...");
my $config = Config::General->new($config_file);
my %conf = $config->getall();
msg("config file read");
msg(Dumper(\%conf) . "\n");

# files to be created in the working directory, or extensions thereof
my $pbs_file     = $conf{pbs_file};       # PBS script name
my $pbs_shebang  = $conf{pbs_shebang};    # shebang for generated PBS file
my $arrayid_ext  = $conf{arrayid_ext};    # extension for arrayid files
my $batch_ext    = $conf{batch_ext};      # extension for generated batch
                                          # file
my $run_ext      = $conf{run_ext};        # extension for submit script
my $prepr_ext    = $conf{prepr_ext};      # extension for preprocessed batch
my $default_log  = $conf{default_log};    # templ. log name
my $default_sh   = $conf{default_sh};     # templ. batch name
my $default_run  = $conf{default_run};    # templ. run name
my $default_pro  = $conf{default_pro};    # templ. prolog name
my $default_epi  = $conf{default_epi};    # templ. epilog name
my $default_pbs  = $conf{default_pbs};    # templ. PBS name
my $default_host = $conf{default_host};   # templ. host file name
my $default_sleep = $conf{default_sleep}; # MPI_Test sleep time

# files to be found in the $worker_dir
# PBS template
my $pbs_tmpl = "$worker_dir$conf{pbs_tmpl_dir}/$pbs_file$conf{pbs_tmpl_ext}";
my $worker_hdr = "${worker_dir}$conf{worker_hdr}";  # worker header file
my $worker = "${worker_dir}$conf{worker}";          # worker executable
my $separator = parse_hdr($worker_hdr);

# some defaults
my $qsub = $conf{qsub};       # qsub command to use in run script
my $email = $conf{email};     # email to send complaints to

# number of cores per node (hardware property
my $cores_per_node = $conf{cores_per_node};

# test whether necessary files can be found and read
check_file($pbs_tmpl, "PBS file template", 1, 0, $email);
check_file($worker_hdr, "worker header file", 1, 0, $email);

# configure command line parsing
Getopt::Long::Configure("no_ignore_case", "pass_through",
			"no_auto_abbrev");

# command line variables and deal with them
my $jobid = undef;
my $retry = 0;
my $enable_prolog = 0;
my $disable_epilog = 0;
my $disable_options = 0;
my $prolog_file = undef;
my $epilog_file = undef;
my $mpi_verbose = undef;
my $master = 0;
my $threaded = 0;
my $sleep = $default_sleep;
my $job_name = undef;
my $directive_prefix = undef;
my $verbose = 0;
my $dryrun = undef;
my $quiet = 0;
my $pbs_array_str = undef;

GetOptions(
       "jobid=s"         => \$jobid,
	   "retry"           => \$retry,
       "enable_prolog"   => \$enable_prolog,
	   "disable_epilog"  => \$disable_epilog,
	   "prolog=s"        => \$prolog_file,
	   "epilog=s"        => \$epilog_file,
	   "disable_options" => \$disable_options,
	   "mpiverbose"      => \$mpi_verbose,
	   "verbose"         => \$verbose,
       "master"          => \$master,
       "threaded=i"      => \$threaded,
       "sleep=i"         => \$sleep,
	   "dryrun"          => \$dryrun,
	   "quiet"           => \$quiet,
	   "help"            => \&show_help,
	   # qsub options that have to be intercepted and ignored
	   "N=s"             => \$job_name,
	   "C=s"             => \$directive_prefix,
	   "t=s"             => \$pbs_array_str);
# if there are additional qsub options, they are in @ARGV and will
# be passed to qsub

# set verbosity for Worker::Utils
$Worker::Utils::verbose = $verbose;

msg("validating options...");
# check for mandatory options
unless (defined $jobid) {
    print STDERR "### error: job ID should be specified\n";
    print_help();
    exit 1;
}
# check whether -N, -C or -t have been specified, if so warn that they
# will be suppressed
suppressed_option('-N', $job_name);
suppressed_option('-C', $directive_prefix);
suppressed_option('-t', $pbs_array_str);
# check whether only prolog or redo prolog is specified
if ($enable_prolog && defined $prolog_file) {
    print STDERR "### error: either original prolog or a new prolog can\n";
    print STDERR "           be executed, both are specified\n";
    exit 3;
}
# check whether only epilog or redo epilog is specified
if (!$disable_epilog && defined $epilog_file) {
    print STDERR "### error: either original epilog or new epilog can\n";
    print STDERR "           be executed, both are specified\n";
    exit 3;
}
check_file($prolog_file, "prolog file") if defined $prolog_file;
check_file($epilog_file, "epilog file") if defined $epilog_file;

# find files related to the specified job ID, check only in the current
# directory since this is supposed to be the working directory for resuming
# the job anyway
my %jobfiles = find_job_files($jobid);

# determine relevant extensions
my $log_ext = compute_file_extension($default_log);
my $sh_ext = compute_file_extension($default_sh);
my $pbs_ext = compute_file_extension($default_pbs);
my $sub_ext = compute_file_extension($default_run);

# determine the job name from the job log file, and make sure this is the
# one that will be used by PBS
$job_name = compute_job_name($jobfiles{$log_ext}, $log_ext);
push(@ARGV, '-N', $job_name);

# if prolog and/or epilog have to be redone, find out the name and check
if ($enable_prolog) {
    my $prolog_ext = compute_file_extension($default_pro);
    $prolog_file = $jobfiles{$prolog_ext};
    check_file($prolog_file, 'prolog file');
}
if (!$disable_epilog) {
    my $epilog_ext = compute_file_extension($default_epi);
    $epilog_file = $jobfiles{$epilog_ext};
    check_file($epilog_file, 'epilog file') if defined $epilog_file;
}

# using the log and the task file, get a list of tasks to be done
my $task_parser = Worker::TaskfileParser->new($separator);
$task_parser->parse($jobfiles{$sh_ext});
my $log_parser = Worker::LogParser->new();
$log_parser->parse($jobfiles{$log_ext});
my $executed_filter = Worker::ExecutedTasksFilter->new();
$executed_filter->set_redo_failed($retry);
$executed_filter->filter([$task_parser->tasks()],
			 [$log_parser->completed()],
			 [$log_parser->failed()]);

# temporary directory created in the working directory, can be deleted
# as soon as the job starts running
my $dir = tempdir($conf{dir_tmpl}, CLEANUP => 0);

# files to be created in the working directory
my $batch_file = "${dir}/${job_name}${batch_ext}";
msg("batch file: '$batch_file'");
my $log_file = $default_log;
msg("log file: '$log_file'");

# create the batch file
msg("creating batch file...");
my $fh = undef;
unless (open($fh, ">$batch_file")) {
    print STDERR "### error: can't open file '$batch_file'\n";
    print STDERR "           for writing: $!\n";
    exit 2;
}
foreach my $task ($executed_filter->tasks) {
    print $fh "$task";
    print $fh "$separator\n";
}
$fh->close();

# initialize Template engine
msg("initializing template engine...");
my $tt_config = {ABSOLUTE => 1};
my $engine = Template->new($tt_config);
msg("template engine initialized");

# parse original PBS file
msg("parsing PBS file...");
my $pbs_parser = Pbs::Parser->new();
my $pbs = $pbs_parser->parse_file($jobfiles{$pbs_ext}, $directive_prefix);
msg("PBS file parsed");

# determine requested ppn, default to hardware value, but only bother
# when work items are threaded
my $ppn = $cores_per_node;
if ($threaded) {
    $ppn = $threaded
}
msg("ppn set to $ppn");

# if the work items are threaded, replace a ppn by the hardware default,
# otherise leave unmodified
my $pbs_directives = $pbs->get_pbs();

# determine basename of prolog/epilog
my $prolog_basename = undef;
if (defined $prolog_file) {
    $prolog_basename = basename($prolog_file);
}
my $epilog_basename = undef;
if (defined $epilog_file) {
    $epilog_basename = basename($epilog_file);
}

# initialize the variables to fill out the PBS template, and create
# PBS file
msg("creating PBS file...");
my $vars = {
    'shebang'        => $pbs_shebang,
    'pbs'            => $pbs_directives,
    'dir'            => "$dir/",
    'worker'         => $worker,
    'verbose'        => $mpi_verbose,
    'prolog'         => $prolog_basename,
    'epilog'         => $epilog_basename,
    'logfile'        => $log_file,
    'master'         => $master,
    'threaded'       => $threaded,
    'core_count'     => "$FindBin::Bin/core_count",
    'sleep'          => $sleep,
    'ppn'            => $ppn,
    'core_count'     => "core-counter",
    'basename'       => $job_name,
    'default_log'    => $default_log,
    'default_pro'    => $default_pro,
    'default_sh'     => $default_sh,
    'default_epi'    => $default_epi,
    'default_run'    => $default_run,
    'default_pbs'    => $default_pbs,
    'default_host'   => $default_host,
    'batch_ext'      => $batch_ext,
    'pbs_file'       => $pbs_file,
    'run_ext'        => $run_ext,
    'mpi_module'     => $conf{mpi_module},
    'module_path'    => $conf{module_path},
    'mpirun'         => $conf{mpirun},
    'mpirun_options' => $conf{mpirun_options},
    };
unless ($engine->process($pbs_tmpl, $vars, $pbs_file)) {
    print STDERR "### error: problem with template,\n";
    print STDERR "           ", $engine->error(), "\n";
    exit 4;
}
msg("PBS file created");

msg("copying files to temp directory '$dir'...");
# copy prolog and epilog to directory if they exist
copy($prolog_file, "$dir/$prolog_basename") if defined $prolog_file;
copy($epilog_file, "$dir/$epilog_basename") if defined $epilog_file;

# copy PBS file to directory
my $pbs_basename = basename($pbs_file);
copy($pbs_file, "$dir/$pbs_basename");
msg("files copied to temp directory '$dir'");

my @run_options = ();

if ($disable_options) {
    @run_options = @ARGV;
} else { # parse run file to obtain options of previous run
    msg("parsing run file to merge run options...");
    my $run_parser = Worker::RunfileParser->new();
    $run_parser->parse($jobfiles{$sub_ext});
    my %previous_options = $run_parser->options();
    my $current_options = hash_options(@ARGV);
    @run_options = quote_options(merge_options($current_options,
					       \%previous_options,
					       ['-t', '-C', '-N']));
    msg("run options merged");
}

# create the submission script
create_run_script("${dir}/${job_name}${run_ext}", @run_options);

# create submission command, execute unless dry run
my $submit_cmd = create_run_cmd(@run_options);
if (defined $dryrun) {
    print "$submit_cmd\n";
} else {
    unless (system($submit_cmd) == 0) {
        print STDERR "### error: failed to submit job: $!\n";
        print STDERR "    $submit_cmd\n";
        exit 3;
    }
}

# succesfully completed wresume
exit 0;

# ----------------------------------------------------------------------------
# function to merge old and new options, giving priority to the latter,
# excluding irrelavant options from the old options
# ----------------------------------------------------------------------------
sub merge_options {
    my ($current_options, $previous_options, $exclude) = @_;
    my @options = ();
    my %temp_options = %{$previous_options};
    foreach my $irrelevant (@{$exclude}) {
        delete $temp_options{$irrelevant};
    }
    foreach my $flag (keys %{$current_options}) {
        $temp_options{$flag} = $current_options->{$flag};
    }
    foreach my $flag (keys %temp_options) {
        push(@options, $flag);
        push(@options, $temp_options{$flag})
            if defined $temp_options{$flag};
    }
    return @options;
}

# ----------------------------------------------------------------------
# creates a shell script to submit the job to the queue system
# ----------------------------------------------------------------------
sub create_run_script {
    my $run_script = shift(@_);
    my $file_name = "${run_script}";
    unless (open(OUT, ">$file_name")) {
	print STDERR "### error: can't create '$file_name': $!\n";
	exit 2;
    }
    print OUT "#!/bin/bash -l\n\n";
    print OUT create_run_cmd(@_), "\n";
    close(OUT);
}

# ----------------------------------------------------------------------
# function to warn when an option that is going to be ignored is passed
# on the command line
# ----------------------------------------------------------------------
sub suppressed_option {
    my ($flag, $value) = @_;
    if (defined $value) {
        print STDERR "### warning: option '$flag' is ignored upon\n";
        print STDERR "             job resume\n";
    }
}

# ----------------------------------------------------------------------
# function to find all files related to the specified job ID, returned as
# hash with extension as key, file name as value
# ----------------------------------------------------------------------
sub find_job_files {
    my ($jobid) = @_;
    msg("find files related to job '$jobid'...");
    my %jobfiles = ();
    my $dh = IO::Dir->new(".") or
	die("### error: can't open current directory: $!");
    while (my $file_name = $dh->read()) {
        if ($file_name =~ /\.(\w+)$jobid$/) {
            my $ext = $1;
            if ($ext ne 'o' && $ext ne 'e') {
                $jobfiles{$ext} = $file_name;
            }
        }
    }
    msg("found " . join(', ', map {"'$_'"} keys %jobfiles));
    return %jobfiles;
}
    
# ----------------------------------------------------------------------
# function to compute job name from job file
# ----------------------------------------------------------------------
sub compute_job_name {
    my ($file_name, $ext) = @_;
    if ($file_name =~ /^(.+)\.$ext[0-9]+$/) {
        return $1;
    } else {
        die("### error: can't determine job name from '$file_name' using '$ext'");
    }
}

# ----------------------------------------------------------------------
# create the job submission command
# ----------------------------------------------------------------------
sub create_run_cmd {
    return "$qsub " . join(" ", quote_options(@_)) . " $pbs_file";
}

# ----------------------------------------------------------------------
# compute the requested resources from the command line arguments
# ----------------------------------------------------------------------
sub get_cmd_line_resources {
    my @values = ();
    while (@_) {
        my $option = shift(@_);
        if ($option eq '-l') {
            if (@_) {
                my $value = shift(@_);
                push(@values, $value);
            }
        } elsif ($option =~ /^-l(.+)$/) {
            push(@values, $1);
        }
    }
    if (@values) {
        return join(',', @values);
    } else {
        return undef;
    }
}

# ----------------------------------------------------------------------
# print the script's help stuff
# ----------------------------------------------------------------------
sub print_help {
    print STDERR <<EOI
### usage: wresume  -jobid <jobID>                             \\
#                  [-enable_prolog  | -prolog <prolog-file> ]  \\
#                  [-disable_epilog | -epilog <epilog-file>]   \\
#                  [-retry]                                    \\
#                  [-disable_options]                          \\
#                  [-threaded <n>]                                 \\
#                  [-sleep <microseconds>]                     \\
#                  [-mpiverbose]                               \\
#                  [-dryrun] [-verbose]                        \\
#                  [-quiet] [-help]                            \\
#                  [<pbs-qsub-options>]
#
#   -jobid <jobID>        : job ID of the job to be resumed
#                           replaced with data from the data file(s) or the
#                           PBS array request option
#   -enable_prolog        : when specified, the prolog of the resumed job
#                           is executed, this is probably not what you want
#   -prolog <prolog-file> : prolog script to be executed before any of the
#                           work items are executed
#   -disable_epilog       : when specified, the epilog of the resumed job
#                           is *not* executed, this is probably not what you
#                           want
#   -epilog <epilog-file> : epilog script to be executed after all the work
#                           items are executed
#   -retry                : failed tasks are executed again, as well as those
#                           that were not finished in the job to be resumed
#   -threaded <n>         : indicates that work items are multithreaded,
#                           running with <n> threads, and ensures that
#                           CPU sets will have all cores,
#                           regardless of ppn, hence each work item will
#                           have <total node cores>/<n> cores for its
#                           threads; for avoiding problems with CPU sets,
#                           choose ppn the same as the number of
#                           physical cores of the target node;
#                           don't use this unless you know what you are
#                           ding
#   -sleep <microseconds> : time for the master to sleep between
#                           MPI_Test to avoid spinning, expressed in
#                           microseconds; don't use this unless you're
#                           really sure what you are doing
#   -disable-options      : when specified, the options that were specified
#                           for the job to be resumed are completely ignored
#   -mpiverbose           : pass verbose flag to the underlying MPI program
#   -verbose              : feedback information is written to standard error
#   -dryrun               : run without actually submitting the job, useful
#   -quiet                : don't show information
#   -help                 : print this help message
#   <pbs-qsub-options>    : options passed on to the queue submission
#                           command, '-N', '-t' and '-C' options are ignored;
#                           these options will override those of the job
#                           that is resumed
EOI
}
# ------------------------------------------------------------------
# shows help and exits
# ----------------------------------------------------------------------------
sub show_help {
    print_help();
    exit 0;
}
# ----------------------------------------------------------------------
# writes a string to the specified file
# ----------------------------------------------------------------------
sub dump2file {
    my ($str, $file) = @_;
    open(OUT, ">$file") or die("Can't open dump file '$file': $!");
    print OUT $str;
    close(OUT);
}
# ----------------------------------------------------------------------
