package Worker::Utils;

use strict;
use warnings;
use base qw( Exporter );

our @EXPORT_OK = qw(
        parse_hdr check_file compute_file_extension msg
        quote_options hash_options get_cmd_line_resources
        create_run_cmd create_run_script dump2file
);
our $verbose = 0;
our $default_email = 'hpcinfo@icts.kuleuven.be';

# ----------------------------------------------------------------------
# parse a C header file to determine the batch file separator
# ----------------------------------------------------------------------
sub parse_hdr {
    my $h_file = shift(@_);
    open(IN, $h_file) or
        die("### error: can't open header file '$h_file': $!");
    while (<IN>) {
        chomp($_);
        if (/^\s*#define\s+SEPARATOR\s+\"(.+)\\n\"$/) {
            close(IN);
            return $1;
        }
    }
    close(IN);
    print STDERR "### error: can't find separator in '$h_file'\n";
    exit 5;
}

# ----------------------------------------------------------------------
# checks whether a given file exists and is readable, if not, print
# error and exit
# ----------------------------------------------------------------------
sub check_file {
    my ($file, $file_type, $is_system, $is_exec, $email) = @_;
    my $contact = ((defined $email) && (length($email) > 0)) ?
	$email : $default_email;
    if (!defined $file || length($file) == 0) {
        print STDERR "### error: $file_type name is undefined or empty\n";
        if ($is_system) {
            print STDERR "           please notify $contact,\n";
            print STDERR "           mentioning this error message\n";
        }
        exit 2;
    }
    my $cond = -e $file && -r $file;
    $cond &&= -x $file if $is_exec;
    unless ($cond) {
        print STDERR "### error: $file_type '$file' can't be read\n";
        if ($is_system) {
            print STDERR "           please notify $contact,\n";
            print STDERR "           mentioning this error message\n";
        }
        exit 2;
    }
}

# ----------------------------------------------------------------------
# compute extension from a file name template
# ----------------------------------------------------------------------
sub compute_file_extension {
    my $templ = shift(@_);
    my $pos = rindex($templ, '.') + 1;
    die("### error: '$templ' seems not to have an extension")
        unless $pos > 0;
    my $ext = substr($templ, $pos);
    $pos = index($ext, "\$");
    $ext = substr($ext, 0, $pos) if $pos > 0;
    return $ext;
}

# ----------------------------------------------------------------------
# write message to STDERR
# ----------------------------------------------------------------------
sub msg {
    my $msg = shift(@_);
    print "$msg\n" if $verbose;
}

# ---------------------------------------------------------------------- 
# escape single and double quotes in strings
# ---------------------------------------------------------------------- 
sub escape {
    my $str = shift(@_);
    $str =~ s/'/\\'/g;
    $str =~ s/"/\\"/g;
    return "'$str'";
}

# ----------------------------------------------------------------------
# quote options list
# ----------------------------------------------------------------------
sub quote_options {
    my @options = ();
    foreach my $option (@_) {
        if ($option =~ /^\-/) {
            push(@options, $option);
        } else {
            push(@options, escape($option));
        }
    }
    return @options;
}

# -----------------------------------------------------------------------
# coompute a hash of command line arguments, flags have undef as value,
# options their specified value
# -----------------------------------------------------------------------
sub hash_options {
    my $hash = {};
    my $prev_opt = undef;
    foreach my $str (@_) {
        if ($str =~ /^\-/) {
            $prev_opt = $str;
            $hash->{$prev_opt} = undef;
        } else {
            $hash->{$prev_opt} = $str;
        }
    }
    return $hash;
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

# ---------------------------------------------------------------------
# create the job submission command
# ---------------------------------------------------------------------
sub create_run_cmd {
    my $qsub = shift(@_);
    my $pbs_file = shift(@_);
    return "$qsub " . join(" ", quote_options(@_)) . " $pbs_file";
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
# writes a string to the specified file
# ----------------------------------------------------------------------
sub dump2file {
    my ($str, $file) = @_;
    open(OUT, ">$file") or die("Can't open dump file '$file': $!");
    print OUT $str;
    close(OUT);
}

1;
