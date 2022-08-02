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
use Worker::Utils qw( parse_hdr check_file msg quote_options );
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

# some defaults
my $qsub = $conf{qsub};       # qsub command to use in run script
my $email = $conf{email};     # email to send complaints to

# number of cores per node (hardware property)
my $cores_per_node = $conf{cores_per_node};

# test whether necessary files can be found and read
check_file($pbs_tmpl, "PBS file template", 1, 0, $email);
check_file($worker_hdr, "worker header file", 1, 0, $email);

# configure command line parsing
Getopt::Long::Configure("no_ignore_case", "pass_through",
			"no_auto_abbrev");

# command line variables and deal with them
my $prolog_file = undef;
my $batch_tmpl = undef;
my $epilog_file = undef;
my @data_files = ();
my $log_file = undef;
my $pbs_array_str = undef;
my $mpi_verbose = undef;
my $master = 0;
my $threaded = 0;
my $sleep = $default_sleep;
my $job_name = undef;
my $directive_prefix = undef;
my $verbose = 0;
my $dryrun = undef;
my $quiet = 0;
my $allow_loose_quotes = undef;
my $escape_char = undef;

GetOptions(
        "prolog=s"             => \$prolog_file,
        "batch=s"              => \$batch_tmpl,
        "epilog=s"             => \$epilog_file,
        "data=s"               => \@data_files,
        "log=s"                => \$log_file,
        "mpiverbose"           => \$mpi_verbose,
        "verbose"              => \$verbose,
        "master"               => \$master,
        "threaded=i"           => \$threaded,
        "sleep=i"              => \$sleep,
        "dryrun"               => \$dryrun,
        "quiet"                => \$quiet,
        "allow_loose_quotes"   => \$allow_loose_quotes,
        "escape_char=s"        => \$escape_char,
        "help"                 => \&show_help,
# qsub options that have to be intercepted
        "N=s"                  => \$job_name,
        "C=s"                  => \$directive_prefix,
        "t=s"                  => \$pbs_array_str,
        );
# if there are additional qsub options, they are in @ARGV and will
# be passed to qsub

# set verbosity for Worker::Utils
$Worker::Utils::verbose = $verbose;

msg("validating options...");
# check for mandatory options
unless (defined $batch_tmpl) {
    print STDERR "### error: batch file template should be specified\n";
    print_help();
    exit 1;
}
unless (scalar(@data_files) > 0 || defined $pbs_array_str) {
    print STDERR "### error: either a data file or an array request \n";
    print STDERR "           should be specified\n";
    print_help();
    exit 1;
}
# check that files, if supplied, can be read
msg("checking file existances...");
check_file($batch_tmpl, "batch template file");
if (scalar(@data_files) > 0) {
    @data_files = split(/,/, join(',', @data_files));
    check_file($_, "data file") foreach @data_files;
}
check_file($prolog_file, "prolog file") if defined $prolog_file;
check_file($epilog_file, "epilog file") if defined $epilog_file;
msg("files exist");

unless (defined $directive_prefix) {
    $directive_prefix = $conf{pbs_prefix};
}

# temporary directory created in the working directory, can be deleted
# as soon as the job starts running
my $dir = tempdir($conf{dir_tmpl}, CLEANUP => 0);

# extract file name from $batch_tmpl
my ($batch_tmpl_file, $batch_path) = fileparse($batch_tmpl);

# files to be created in the working directory
my $batch_file = "${dir}/${batch_tmpl_file}${batch_ext}";
msg("batch file: '$batch_file'");
$log_file = $default_log unless defined $log_file;
msg("log file: '$log_file'");
my $separator = parse_hdr($worker_hdr);

# initialize Template engine
msg("initializing template engine...");
my $tt_config = {ABSOLUTE => 1};
my $engine = Template->new($tt_config);
msg("template engine initialized");

# parse batch file template
msg("parsing batch template file...");
my $pbs_parser = Pbs::Parser->new();
$pbs_parser->set_prefix($directive_prefix);
my $pbs = $pbs_parser->parse_file($batch_tmpl);
unless ($pbs->has_script()) {
    print STDERR "### warning: batch template file '$batch_tmpl'\n";
    print STDERR "             seems to contain no actual work\n";
}
msg("batch template file parsed");

# create data providers
msg("creating providers...");
my @providers = ();
# create the PBS array ID file if -t was supplied
my $arrayid_file_name = "${batch_tmpl}${arrayid_ext}";
if (defined $pbs_array_str) {
    create_arrayid_file($arrayid_file_name,
            $pbs_parser->parse_arrayid_str($pbs_array_str));
    push(@providers, Worker::CsvProvider->new($arrayid_file_name,
                                              $allow_loose_quotes,
                                              $escape_char));
    msg("array id provider created");
}

# create the appropriate provider
foreach my $data_file (@data_files) {
    eval {
        push(@providers, Worker::CsvProvider->new($data_file,
                                                  $allow_loose_quotes,
                                                  $escape_char));
    };
    if ($@) {
        print STDERR "### error parsing '$data_file': $@";
        exit 7;
    }
    msg("data file provider '$data_file' created");
}

my $provider = Worker::DataProvider->new(@providers);
msg("all providers created");

# get all variable names and preprocss batch file template string
my @variables = $provider->get_vars();
msg("preprocessing script for " . join(', ', map {"'$_'"} @variables) . '...');
my $batch_str = preprocess($pbs->get_script(), @variables);
msg("script preprocessed");
dump2file($batch_str, "${batch_tmpl}${prepr_ext}") if $verbose;

my $job_size = 0;

# create the batch file
msg("creating batch file...");
my $fh = undef;
unless (open($fh, ">$batch_file")) {
    print STDERR "### error: can't open file '$batch_file'\n";
    print STDERR "           for writing: $!\n";
    exit 2;
}
while ($provider->has_next()) {
    $job_size++;
    msg("work item $job_size...");
    my $vars = $provider->get_next();
    unless ($engine->process(\$batch_str, $vars, $fh)) {
        print STDERR "### error: problem with template,\n";
        print STDERR "           ", $engine->error(), "\n";
        exit 4;
    }
    print $fh "\n$separator\n";
}
close($fh);
$provider->destroy();
msg("batch file created");

print "total number of work items: $job_size\n" unless $quiet;

# arrayid_file is no longer needed, so it can be removed
msg("deleting arrayid file...");
unlink($arrayid_file_name) if defined $pbs_array_str;
    
# check whether PBS script had an explicit shebang, if not, use
# default, and issue a warning
if ($pbs->has_shebang()) {
    $pbs_shebang = $pbs->get_shebang();
} else {
    print STDERR "### warning: PBS script contains no shebang line,\n";
    print STDERR "#            please refer to qsub's man page\n";
}

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
msg("creating PBS file..");
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
    'sleep'          => $sleep,
    'ppn'            => $ppn,
    'basename'       => $batch_tmpl_file,
    'default_log'    => $default_log,
    'default_pro'    => $default_pro,
    'default_sh'     => $default_sh,
    'default_epi'    => $default_epi,
    'default_run'    => $default_run,
    'default_pbs'    => $default_pbs,
    'default_host'   => $default_host,
    'batch_ext'      => $batch_ext,
    'run_ext'        => $run_ext,
    'pbs_file'       => $pbs_file,
    'unload_modules' => $conf{unload_modules},
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

# restore qsub options
msg("restoring command line options");
# -N: if no job name was specified either on the command line or in the
# PBS file, leave it to qsub
if (defined $job_name) {
    unshift(@ARGV, '-J', $job_name);
} elsif (!$pbs->has_name()) {
    $job_name = compute_pbs_jobname($job_name, $pbs, $batch_tmpl);
    unshift(@ARGV, '-J', $job_name);
}
# -C
if (defined $directive_prefix && $directive_prefix ne $Pbs::Parser::DEFAULT_PREFIX) {
    unshift(@ARGV, '-C', $directive_prefix);
}
# -t: do not put this back, this is for PBS array requests, and is
#     not supported by Moab

# create the submission script
create_run_script("${dir}/${batch_tmpl_file}${run_ext}", @ARGV);

# copy prolog and epilog to directory if they exist
copy($prolog_file, "$dir/$prolog_basename") if defined $prolog_file;
copy($epilog_file, "$dir/$epilog_basename") if defined $epilog_file;

# copy PBS file to directory
my $pbs_basename = basename($pbs_file);
copy($pbs_file, "$dir/$pbs_basename");

# create submission command, execute unless dry run
my $submit_cmd = create_run_cmd(@ARGV);
if (defined $dryrun) {
    print "$submit_cmd\n";
} else {
    unless (system($submit_cmd) == 0) {
	print STDERR "### error: failed to submit job: $!\n";
	print STDERR "    $submit_cmd\n";
	exit 3;
    }
    unlink($pbs_file) unless $verbose;
}

# succesfully completed wsub
exit 0;

# ----------------------------------------------------------------------
# Computes the job name:
#  1) if -N is a command line option, use it;
#  2) if -N is a PBS directive in the batch file template, use that;
#  3) use the bash file template's basename.
# Semantics in accordance with torque's qsub.
# ----------------------------------------------------------------------
sub compute_pbs_jobname {
    my ($pbs_jobname, $pbs, $batch_tmpl) = @_;
    my $job_name = $pbs_jobname;
    if (!defined $job_name && $pbs->has_name()) {
	$job_name = $pbs->get_name();
    }
    if (!defined $job_name) {
	my $lpos = rindex($batch_tmpl, '/') + 1;
	$job_name = substr($batch_tmpl, $lpos);
    }
    return $job_name;
}

# ----------------------------------------------------------------------
# preprocess the batch template file string to convert $var to [%var%]
# if they occur in the parameter list
# ----------------------------------------------------------------------
sub preprocess {
    my $batch_in = shift(@_);
    my $sh1 = IO::Scalar->new(\$batch_in);
    my $str = '';
    my $sh2 = IO::Scalar->new(\$str);
    my $preprocessor = Worker::Preprocessor->new(@_);
    $preprocessor->preprocess_file($sh1, $sh2);
    $sh1->close();
    $sh2->close();
    return $str;
}

# ----------------------------------------------------------------------
# create file containing array IDs derived from -t array request options
# ----------------------------------------------------------------------
sub create_arrayid_file {
    my $pbs_arrayid_file = shift(@_);
    unless (open(OUT, ">$pbs_arrayid_file")) {
	print STDERR "### error: can't open file '$pbs_arrayid_file'\n";
	exit 2;
    }
    print OUT "PBS_ARRAYID\n";
    print OUT "$_\n" foreach @_;
    close(OUT);
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
    print OUT "#!/usr/bin/env bash\n\n";
    print OUT create_run_cmd(@_), "\n";
    close(OUT);
}
# ---------------------------------------------------------------------
# create the job submission command
# ---------------------------------------------------------------------
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
### usage: wsub  -batch <batch-file>          \\
#                [-data <data-files>]         \\
#                [-prolog <prolog-file>]      \\
#                [-epilog <epilog-file>]      \\
#                [-log <log-file>]            \\
#                [-mpiverbose]                \\
#                [-threaded <n>]              \\
#                [-sleep <microseconds>]      \\
#                [-dryrun] [-verbose]         \\
#                [-quiet] [-help]             \\
#                [-t <array-req>]             \\
#                [<pbs-qsub-options>]
#
#   -batch <batch-file>   : batch file template, containing variables to be
#                           replaced with data from the data file(s) or the
#                           PBS array request option
#   -data <data-files>    : comma-separated list of data files (default CSV
#                           files) used to provide the data for the work
#                           items
#   -prolog <prolog-file> : prolog script to be executed before any of the
#                           work items are executed
#   -epilog <epilog-file> : epilog script to be executed after all the work
#                           items are executed
#   -mpiverbose           : pass verbose flag to the underlying MPI program
#   -verbose              : feedback information is written to standard error
#   -dryrun               : run without actually submitting the job, useful
#   -quiet                : don't show information
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
#   -t <array-req>        : qsub's PBS array request options, e.g., 1-10
#   -help                 : print this help message
#   -allow_loose_quotes   : enable CSV loose quote parsing mode, do not
#                           use this unless you really know what you are
#                           doing
#   -escape_char <c>      : use <c> as escape character for the CSV parser,
#                           do not use this unless you really know what
#                           you are doing
#   <pbs-qsub-options>    : options passed on to the queue submission
#                           command
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
