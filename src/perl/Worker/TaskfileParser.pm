package Worker::TaskfileParser;

use strict;
use warnings;
use IO::File;

# ----------------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------------
sub new {
    my ($pkg, $separator) = @_;
    my $self = bless {}, $pkg;
    $self->{separator} = $separator;
    $self->{tasks} = [];
    return $self;
}

# ----------------------------------------------------------------------------
# method that resets the parse result, to be called when starting to parse
# a new task file
# ----------------------------------------------------------------------------
sub reset {
    my $self = shift(@_);
    delete $self->{tasks};
    $self->{tasks} = [];
}

# ----------------------------------------------------------------------------
# method that returns the tasks from the file that has been parsed
# ----------------------------------------------------------------------------
sub tasks {
    my $self = shift(@_);
    return @{$self->{tasks}};
}

# ----------------------------------------------------------------------------
# method that returns the number of tasks in the task file that has been
# parsed
# ----------------------------------------------------------------------------
sub nr_tasks {
    my $self = shift(@_);
    return scalar(@{$self->{tasks}});
}

# ----------------------------------------------------------------------------
# method that parses a task file
# ----------------------------------------------------------------------------
sub parse {
    my ($self, $task_file) = @_;
    my $fh = IO::File->new($task_file, 'r') or
	die("### error: can't open task file '$task_file': $!");
    my $task = '';
    while (my $line = <$fh>) {
	if ($line !~ /^$self->{separator}/) {
	    $task .= $line;
	} else {
	    push(@{$self->{tasks}}, $task);
	    $task = '';
	}
    }
    $fh->close();
}

1;
