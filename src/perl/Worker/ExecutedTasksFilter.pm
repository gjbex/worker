package Worker::ExecutedTasksFilter;

use strict;
use warnings;
use Set::Scalar;

sub new {
    my $pkg = shift(@_);
    my $self = bless {tasks => [], task_ids => []}, $pkg;
    return $self;
}

sub should_redo_failed {
    my $self = shift(@_);
    return $self->{redo_failed};
}

sub set_redo_failed {
    my ($self, $redo_failed) = @_;
    $self->{redo_failed} = $redo_failed;
}

sub reset {
    my $self = shift(@_);
    delete $self->{tasks};
    $self->{tasks} = [];
    delete $self->{task_ids};
    $self->{task_ids} = [];
}

sub nr_tasks {
    my $self = shift(@_);
    return scalar(@{$self->{tasks}});
}

sub tasks {
    my $self = shift(@_);
    return @{$self->{tasks}};
}

sub task_ids {
    my $self = shift(@_);
    return @{$self->{task_ids}};
}

sub filter {
    my ($self, $tasks, $completed, $failed) = @_;
    my $task_ids = Set::Scalar->new(1..scalar(@$tasks));
    $completed = Set::Scalar->new(@$completed);
    $completed->insert(@$failed) unless $self->should_redo_failed();
    my $task_ids_todo = $task_ids - $completed;
    push(@{$self->{task_ids}}, sort {$a <=> $b} $task_ids_todo->elements());
    foreach my $task_id (@{$self->{task_ids}}) {
	push(@{$self->{tasks}}, $tasks->[$task_id - 1]);
    }
}
    
1;
