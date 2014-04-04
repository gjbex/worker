package Worker::Preprocessor;
# ----------------------------------------------------------------------------
# Module for shell to Template Toolkit preprocessing.
# The constructor takes a list of variable names that should be of the form
# [A-Za-z]\w+.  When the preprocess() or preprocess_file() method is called,
# the string or file will be scanned for each variable name.  If an expression
# of the form $var or ${var} is found, it is replaced by [%var%] for
# subsequent processing by CPAN's Template Toolkit.
# ----------------------------------------------------------------------------
use strict;
use warnings;
use Carp;

# ----------------------------------------------------------------------------
# constructor, takes a list of variable names
# ----------------------------------------------------------------------------
sub new {
    my $pkg = shift(@_);
    my $proc = bless {vars => {}}, $pkg;
    $proc->add_var(@_);
    return $proc;
}

# ----------------------------------------------------------------------------
# adds additional variables to preprocessor
# ----------------------------------------------------------------------------
sub add_var {
    my $self = shift(@_);
    foreach my $var (@_) {
	if ($var =~ /^[A-Za-z]\w*$/) {
	    $self->{vars}->{$var} = 1;
	} else {
	    croak("### error: variable name '$var' is not in required format");
	}
    }
}

# ----------------------------------------------------------------------------
# return all variables the preprocessor is monitoring
# ----------------------------------------------------------------------------
sub get_vars {
    my $self = shift(@_);
    return keys %{$self->{vars}};
}

# ----------------------------------------------------------------------------
# checks whether the preprocessor monitors the given variable name
# ----------------------------------------------------------------------------
sub has {
    my ($self, $var) = @_;
    return exists $self->{vars}->{$var};
}

# ----------------------------------------------------------------------------
# preprocess a string
# ----------------------------------------------------------------------------
sub preprocess {
    my ($self, $str) = @_;
    foreach my $var ($self->get_vars()) {
	$str =~ s/\$$var\b/[%$var%]/g;
	$str =~ s/\$\{$var\}/[%$var%]/g;
    }
    return $str;
}

# ----------------------------------------------------------------------------
# preprocess a file handle, and write the result to a file handle, the caller
# is responsible for opening and closing the handles.
# ----------------------------------------------------------------------------
sub preprocess_file {
    my ($self, $ih, $oh) = @_;
    while (<$ih>) {
	print $oh $self->preprocess($_);
    }
}

# ----------------------------------------------------------------------------
# serializes the preprocessor for debugging
# ----------------------------------------------------------------------------
sub to_string {
    my $self = shift(@_);
    return join(', ', $self->get_vars());
}

1;
