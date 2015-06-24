package Worker::LogParser;
# ----------------------------------------------------------------------
# Module for parsing a Worker log file
# ----------------------------------------------------------------------
use strict;
use warnings;
use Carp;
use IO::File;
use Set::Scalar;

# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------
sub new {
    my $pkg = shift(@_);
    my $self = bless {
        started => Set::Scalar->new(),
        completed => Set::Scalar->new(),
        failed    => Set::Scalar->new()}, $pkg;
    return $self;
}

# ----------------------------------------------------------------------
# method that resets the parse result, to be called when starting to parse
# a new log file
# -----------------------------------------------------------------------
sub reset {
    my $self = shift(@_);
    $self->{completed}->clear;
    $self->{failed}->clear;
    $self->{started}->clear;
}

# ----------------------------------------------------------------------
# method that returns the task ID of succesfully completed tasks in the
# file that has been parsed
# ----------------------------------------------------------------------
sub completed {
    my $self = shift(@_);
    return sort {$a <=> $b} $self->{completed}->members();
}

# ----------------------------------------------------------------------
# method that returns the number of succesfully completed tasks in the log
# file that has been parsed
# ---------------------------------------------------------------------
sub nr_completed {
    my $self = shift(@_);
    return $self->{completed}->size();
}

# ----------------------------------------------------------------------
# method that returns the task ID of failed tasks in the file that has
# been parsed
# ----------------------------------------------------------------------
sub failed {
    my $self = shift(@_);
    return sort {$a <=> $b} $self->{failed}->members();
}

# ----------------------------------------------------------------------
# method to check whether failed tasks were found
# ----------------------------------------------------------------------
sub has_failed {
    my $self = shift(@_);
    return !$self->{failed}->is_empty();
}

# ----------------------------------------------------------------------
# method that returns the number of failed jobs in the log file that has
# been parsed
# ----------------------------------------------------------------------
sub nr_failed {
    my $self = shift(@_);
    return $self->{failed}->size();
}

# ---------------------------------------------------------------------
# method that returns the task ID of started tasks in the file that has
# been parsed
# ---------------------------------------------------------------------
sub started {
    my $self = shift(@_);
    return sort {$a <=> $b} $self->{started}->members();
}

# ----------------------------------------------------------------------
# method to check whether started tasks were found
# ----------------------------------------------------------------------
sub has_started {
    my $self = shift(@_);
    return !$self->{started}->is_empty();
}

# ----------------------------------------------------------------------
# method that returns the number of started jobs in the log file that
# has been parsed
# ----------------------------------------------------------------------
sub nr_started {
    my $self = shift(@_);
    return $self->{started}->size();
}

# ---------------------------------------------------------------------
# method that parses a Worker log file represented by its file
# name
# ---------------------------------------------------------------------
sub parse {
    my ($self, $file) = @_;
    my $fh = IO::File->new($file, 'r') or
	croak("### error: can't open log file '$file': $!");
    $self->parse_file($fh);
    $fh->close();
}

# ---------------------------------------------------------------------
# method that parses a log file represented by an opened file handle,
# only lines containing 'completed' or 'failed' are taken into account
# ---------------------------------------------------------------------
sub parse_file {
    my ($self, $fh) = @_;
    while (my $line = <$fh>) {
        chomp($line);
        if ($line =~ /^(\d+)\s+completed/) {
            $self->{completed}->insert($1);
            if ($self->{failed}->contains($1)) {
                $self->{failed}->delete($1);
            }
        } elsif ($line =~ /^(\d+)\s+failed/) {
            if (!$self->{completed}->contains($1)) {
                $self->{failed}->insert($1);
            }
        } elsif ($line =~ /^(\d+)\s+startted/) {
            $self->{started}->insert($1);
        }
    }
}

1;
