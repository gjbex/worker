package Worker::DataProvider;

use strict;
use warnings;

# ----------------------------------------------------------------------
# constructor, takes a list of providers as input
# ----------------------------------------------------------------------
sub new {
    my $pkg = shift(@_);
    my $self = bless {provider_list => []}, $pkg;
    foreach my $provider (reverse @_) {
        $self->add_provider($provider);
    }
    return $self;
}

# ------------
# Interface methods
# ----------------------------------------------------------------------
# checks whether a sets of variables is available
# ----------------------------------------------------------------------------
sub has_next {
    my $self = shift(@_);
    foreach my $provider ($self->get_providers()) {
        return 0 unless $provider->has_next();
    }
    return 1;
}

# ----------------------------------------------------------------------
# returns the next set of variables as a hash reference
# ----------------------------------------------------------------------
sub get_next {
    my $self = shift(@_);
    my $all_vars = {};
    foreach my $provider ($self->get_providers()) {
        my $vars = $provider->get_next();
        foreach my $name (keys %$vars) {
            $all_vars->{$name} = $vars->{$name};
        }
    }
    return $all_vars;
}

# ----------------------------------------------------------------------
# returns a list of all variables in the CSV files
# ----------------------------------------------------------------------
sub get_vars {
    my $self = shift(@_);
    my @vars = ();
    push(@vars, $_->get_vars()) foreach $self->get_providers();
    return @vars;
}

# ----------------------------------------------------------------------
# makes sure all used resources are cleaned up, must be called when done
# ----------------------------------------------------------------------
sub destroy {
    my $self = shift(@_);
    $_->destroy() foreach $self->get_providers();
}

# -----------------
# Implementation methods
# ----------------------------------------------------------------------
sub get_providers {
    my $self = shift(@_);
    return @{$self->{provider_list}};
}

sub add_provider {
    my ($self, $provider) = @_;
    push(@{$self->{provider_list}}, $provider);
}

1;
