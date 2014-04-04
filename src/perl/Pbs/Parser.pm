package Pbs::Parser;
# ----------------------------------------------------------------------------
# module to parse PBS files, follows the specifications of the qsub manpage
# as close as possible
# ----------------------------------------------------------------------------
use strict;
use warnings;

use lib "$ENV{WORKER_DIR}/lib/perl";
use Pbs::Description;

# ----------------------------------------------------------------------------
# constructor, takes a PBS file as an argument, and optionally, a PBS
# directive prefix (defaults to '#PBS'
# ----------------------------------------------------------------------------
sub new {
    my $pkg = shift(@_);
    my $self = bless {prefix  => '#PBS'}, $pkg;
    return $self;
}

# ----------------------------------------------------------------------------
# sets the PBS prefix to use for parsing
# ----------------------------------------------------------------------------
sub set_prefix {
    my ($self, $prefix) = @_;
    $self->{prefix} = $prefix;
}

# ----------------------------------------------------------------------------
# parse the given PBS file
# ----------------------------------------------------------------------------
sub parse_file {
    my ($self, $file) = @_;
    my $pbs = Pbs::Description->new();
    my $state = 'INIT';
    open(IN, $file) or die("Can't open PBS file '$file': $!");
    while (<IN>) {
        if (/^\s*(:|\#!.+?)\s*$/) {
            $pbs->{shebang} = $1;
            $state = 'pbs';
        } elsif (/^\s*$self->{prefix}\s+(.+?)\s*$/ && $state eq 'pbs') {
            $pbs->{$state} .= $_;
            my $option = $1;
            if ($option =~ /^(-[A-Za-z])\s*(.*)$/) {
                my $flag = $1;
                my $value = $2;
                $pbs->add_option($flag, $value);
                $pbs->{has_pbs} = 1;
            }
        } elsif (/^\s*$/) {
            $pbs->{$state} .= $_;
        } elsif (/^\s*\#/) {
            $pbs->{$state} .= $_;
        } elsif ($state eq 'script') {
            $pbs->{$state} .= $_;
        } else {
            $state = 'script';
            $pbs->{$state} .= $_;
            $pbs->{has_script} = 1;
        }
    }
    close(IN);
    return $pbs;
}

# ----------------------------------------------------------------------------
# parses a PBS resource string, returning a hash reference with the results,
# takes a hash reference as an optional second argument to populate, rather
# than a new hash reference
# ----------------------------------------------------------------------------
sub parse_pbs_resources {
    my ($self, $pbs_resource_str, $pbs_resources) = @_;
    $pbs_resources = {} unless defined $pbs_resources;
    my @resources = split(/,/, $pbs_resource_str);
    foreach my $resource (@resources) {
	my ($key, $value) = split(/=/, $resource);
	$pbs_resources->{$key} = $value;
    }
    return $pbs_resources;
}

# ----------------------------------------------------------------------------
# for more flexibility, recompute nodes to take info account ppn, the
# argument is a PBS resource hash reference as returned by, e.g., 
# parse_pbs_resources()
# ----------------------------------------------------------------------------
sub recompute_nodes {
    my ($self, $pbs_resources) = @_;
    if (exists $pbs_resources->{ppn}) {
	if (exists $pbs_resources->{nodes}) {
	    $pbs_resources->{nodes} *= $pbs_resources->{ppn};
	} else {
	    $pbs_resources->{nodes} = $pbs_resources->{ppn};
	}
	delete $pbs_resources->{ppn};
    }
}

# ----------------------------------------------------------------------------
# recomputes walltime, e.g., to convert individual job time to total
# job time, the argument is a PBS resource hash reference as returned
# by, e.g., parse_pbs_resources(), and the total number of work items
# to compute
# ----------------------------------------------------------------------------
sub recompute_walltime {
    my ($self, $pbs_resources, $job_size) = @_;
    if (exists $pbs_resources->{walltime}) {
	my $seconds = walltime2seconds($pbs_resources->{walltime});
	$seconds = int($seconds*$job_size/$pbs_resources->{nodes}) + 1;
	$pbs_resources->{walltime} = seconds2walltime($seconds);
    }
}
# ----------------------------------------------------------------------------
# converts from walltime to seconds
sub walltime2seconds {
    my $walltime = shift(@_);
    my ($hours, $minutes, $seconds) = split(/:/, $walltime);
    return 3600*$hours + 60*$minutes + $seconds;
}
# ----------------------------------------------------------------------------
# converts from seconds to walltime
sub seconds2walltime {
    my $seconds = shift(@_);
    my $hours = int($seconds/3600);
    $seconds = $seconds % 3600;
    my $minutes = int($seconds/60);
    $seconds %= 60;
    return sprintf("%02d:%02d:%02d", $hours, $minutes, $seconds);
}

# ----------------------------------------------------------------------------
# parses an PBS array request option value and returns a sorted list of
# unique IDs, warns on duplicates
# ----------------------------------------------------------------------------
sub parse_arrayid_str {
    my ($self, $pbs_array_str) = @_;
    my %ids = ();
    my @id_strs = split(/,/, $pbs_array_str);
    foreach my $id_str (@id_strs) {
	if ($id_str =~ /^(\d+)$/) {
	    my $id = $1;
	    if (exists $ids{$id}) {
		print STDERR "### warning: duplicate array id '$id'\n";
	    } else {
		$ids{$id} = 1;
	    }
	} elsif ($id_str =~ /^(\d+)-(\d+)$/) {
	    foreach my $id ($1..$2) {
		if (exists $ids{$id}) {
		    print STDERR "### warning: duplicate array id '$id'\n";
		} else {
		    $ids{$id} = 1;
		}
	    }
	} else {
	    print STDERR "### error: invalid array request string:\n";
	    print STDERR "           '$pbs_array_str'\n";
	    exit 3;
	}
    }
    return sort {$a <=> $b} keys %ids;
}

1;

