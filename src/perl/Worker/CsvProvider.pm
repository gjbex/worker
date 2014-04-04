package Worker::CsvProvider;

use strict;
use warnings;
use Carp;
use Text::CSV;

# ------------------------------------------------------------------------ 
# constructor, takes the name of a CSV file
# ------------------------------------------------------------------------
sub new {
    my ($pkg, $file) = @_;
    my $self = bless {
	file       => $file,
	cvs        => undef,
	fh         => undef,
	vars       => [],
	current    => undef,
	}, $pkg;
    $self->init(@_);
    return $self;
}

# ------------------
# Interface methods
# ------------------------------------------------------------------------
# checks whether a sets of variables is available
# ------------------------------------------------------------------------
sub has_next {
    my $self = shift(@_);
    return defined $self->{current};
}

# ------------------------------------------------------------------------
# returns the next set of variables as a hash reference
# ------------------------------------------------------------------------
sub get_next {
    my $self = shift(@_);
    if ($self->has_next()) {
        my $row = $self->{current};
        $self->{current} = $self->{csv}->getline($self->{fh});
        my $result = {};
        my @names = $self->get_vars();
        for (my $i = 0; $i < scalar(@names); $i++) {
            $result->{$names[$i]} = $row->[$i];
        }
        return $result;
    } else {
        return undef;
    }
}

# ------------------------------------------------------------------------
# returns a list of all variables in the CSV files
# ------------------------------------------------------------------------
sub get_vars {
    my $self = shift(@_);
    return @{$self->{vars}};
}

# ------------------------------------------------------------------------
# makes sure all used resources are cleaned up, must be called when done
# ------------------------------------------------------------------------
sub destroy {
    my $self = shift(@_);
    close($self->{fh});
}

# -----------------------
# Implementation methods
# ------------------------------------------------------------------------
# initializes the provider by creating a Text::CSV object, openining the
# CSV file, reading the first line to extract (and check) the column
# names for the variable names and reads the second line to prepare for
# has_next(), get_next()
# ------------------------------------------------------------------------
sub init {
    my $self = shift(@_);
    $self->{csv} = Text::CSV->new() or
        die("### error: can't init CSV " . Text::CSV->error_diag());
    open($self->{fh}, $self->{file}) or
        croak("### error: can't open file '$self->{file}': $!\n");
    if (my $row = $self->{csv}->getline($self->{fh})) {
        my %headers = ();
        foreach my $header (reverse @$row) {
            if ($header =~ /^\s*([A-Za-z]\w*)\s*$/) {
                cluck("### warning: duplicate column name '$1'\n")
                    if exists $headers{$1};
                unshift(@{$self->{vars}}, $1);
            } else {
                croak("### error: invalid column name '$header'\n");
            }
        }
        $self->{current} = $self->{csv}->getline($self->{fh});
    } else {
        croak("### error: data file '$self->{file}' seems to be empty\n");
    }
}

1;

