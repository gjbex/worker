package Worker::RunfileParser;

use strict;
use warnings;
use IO::File;
use Text::ParseWords qw( shellwords );
use Worker::Utils qw( hash_options );

sub new {
    my $pkg = shift(@_);
    my $self = bless {options => {}}, $pkg;
    return $self;
}

sub reset {
    my $self = shift(@_);
    delete $self->{options};
    $self->{options} = {};
}

sub qsub {
    my $self = shift(@_);
    return $self->{qsub};
}

sub options {
    my $self = shift(@_);
    return %{$self->{options}};
}

sub pbs {
    my $self = shift(@_);
    return $self->{pbs};
}

sub parse {
    my ($self, $run_file) = @_;
    my @options = ();
    my $fh = IO::File->new($run_file, 'r') or
	die("### error: can't open run file '$run_file': $!");
    while (my $line = <$fh>) {
	next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
	# remove submission command at start of line
	$line =~ s/^\s*(\S+)\s+//;
	$self->{qsub} = $1;
	# remove PBS script at end of line
	$line =~ s/\s+(\S+)\s*$//;
	$self->{pbs} = $1;
	@options = shellwords($line);
	last;
    }
    $fh->close();
    $self->{options} = hash_options(@options);
}

1;
