package Pbs::Description;
# ----------------------------------------------------------------------------
# module to parse PBS files, follows the specifications of the qsub manpage
# as close as possible
# ----------------------------------------------------------------------------
use strict;
use warnings;

# ----------------------------------------------------------------------------
# constructor, takes a PBS file as an argument, and optionally, a PBS
# directive prefix (defaults to '#PBS'
# ----------------------------------------------------------------------------
sub new {
    my ($pkg, $prefix) = @_;
    my $self = bless {options    => {},
		      prefix     => '#PBS',
		      shebang    => undef,
		      pbs        => '',
		      has_pbs    => 0,
		      script     => '',
		      has_script => 0
		      }, $pkg;
    if (defined $prefix) {
	$self->set_prefix($prefix);
    }
    return $self;
}

# ----------------------------------------------------------------------------
# checks whether the PBS file had a shebang
# ----------------------------------------------------------------------------
sub has_shebang {
    my $self = shift(@_);
    return exists $self->{shebang};
}

# ----------------------------------------------------------------------------
# returns shebang
# ----------------------------------------------------------------------------
sub get_shebang {
    my $self = shift(@_);
    return $self->{shebang};
}

# ----------------------------------------------------------------------------
# checks whether the PBS file had PBS directives
# ----------------------------------------------------------------------------
sub has_pbs {
    my $self = shift(@_);
    return $self->{has_pbs};
}

# ----------------------------------------------------------------------------
# returns PBS directives part of the PBS file
# ----------------------------------------------------------------------------
sub get_pbs {
    my $self = shift(@_);
    return $self->{pbs};
}

# ----------------------------------------------------------------------------
# checks whether the PBS file had an actual script part
# ----------------------------------------------------------------------------
sub has_script {
    my $self = shift(@_);
    return $self->{has_script};
}

# ----------------------------------------------------------------------------
# returns actual script, i.e., no shebang, no PBS directives
# ----------------------------------------------------------------------------
sub get_script {
    my $self = shift(@_);
    return $self->{script};
}

# ----------------------------------------------------------------------------
# checks whether the PBS description has a name
# ----------------------------------------------------------------------------
sub has_name {
    my $self = shift(@_);
    return $self->has_option('-N');
}

# ----------------------------------------------------------------------------
# get the PBS job name, undef if not specified
# ----------------------------------------------------------------------------
sub get_name {
    my $self = shift(@_);
    return $self->get_option('-N');
}


# ----------------------------------------------------------------------------
# get the (accumulated) PBS resource string, undef if not specified
# ----------------------------------------------------------------------------
sub get_resources {
    my $self = shift(@_);
    return $self->get_option('-l');
}

# ----------------------------------------------------------------------------
# get an option, specified by flag, e.g., '-m'
# ----------------------------------------------------------------------------
sub get_option {
    my ($self, $flag) = @_;
    if ($self->has_option($flag)) {
	return $self->{options}->{$flag};
    } else {
	return undef;
    }
}

# ----------------------------------------------------------------------------
# checks whether the PBS file sets the options specified by flag, e.g., '-m'
# ----------------------------------------------------------------------------
sub has_option {
    my ($self, $flag) = @_;
    return exists $self->{options}->{$flag};
}

# ----------------------------------------------------------------------------
# sets the PBS directive prefix string
# ----------------------------------------------------------------------------
sub set_prefix {
    my ($self, $prefix) = @_;
    $self->{prefix} = $prefix;
}

# ----------------------------------------------------------------------------
# add an option, flag and value are given
# ----------------------------------------------------------------------------
sub add_option {
    my ($self, $flag, $value) = @_;
    if (($flag eq '-l' || $flag eq '-M' || $flag eq '-u' ||
	 $flag eq '-v' || $flag eq '-W') && $self->has_option($flag)) {
	$self->{options}->{$flag} .= ",$value";
    } else {
	$self->{options}->{$flag} = $value;
    }
}

1;
