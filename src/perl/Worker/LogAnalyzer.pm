package Worker::LogAnalyzer;
# ----------------------------------------------------------------------
# Module for analyzing a Worker log file
# ----------------------------------------------------------------------
use strict;
use warnings;
use Carp;
use Date::Parse;
use DBD::SQLite;
use DBI;
use IO::File;

# ----------------------------------------------------------------------
# constructor
# ----------------------------------------------------------------------
sub new {
    my $pkg = shift(@_);
    my $db_name = scalar(@_) > 0 ? shift(@_) : ':memory:';
    my $self = bless {
        dbh => DBI->connect("dbi:SQLite:dbname=$db_name", '', '')
    }, $pkg;
    $self->init();
    return $self;
}

# ----------------------------------------------------------------------
# initialize internal database
# ----------------------------------------------------------------------
sub init {
    my $self = shift(@_);
    my $create_work_items = qq(
        CREATE TABLE work_items (
            work_item   INTEGER    PRIMARY KEY,
            worker_id   INTEGER,
            start_time  INTEGER
        );
    );
    my $create_results = qq(
        CREATE TABLE results (
            work_item   INTEGER    PRIMARY KEY,
            exit_code   INTEGER,
            end_time    INTEGER,
            FOREIGN KEY (work_item) REFERENCES work_items (work_item)
        );
    );
    $self->{dbh}->do($create_work_items);
    $self->{dbh}->do($create_results);
    my $insert_start = qq(
        INSERT INTO work_items (work_item, worker_id, start_time)
            VALUES (?, ?, ?);
    );
    $self->{start_insert_stmt} = $self->{dbh}->prepare($insert_start);
    my $insert_end = qq(
        INSERT INTO results (work_item, exit_code, end_time)
            VALUES (?, ?, ?);
    );
    $self->{end_insert_stmt} = $self->{dbh}->prepare($insert_end);
}

# ----------------------------------------------------------------------
# method that resets the parse result, to be called when starting to parse
# a new log file
# -----------------------------------------------------------------------
sub reset {
    my $self = shift(@_);
    my $drop_work_items = qq(
        DROP TABLE work_item;
    );
    $self->{dbh}->do($drop_work_items);
    my $drop_results = qq(
        DROP TABLE results;
    );
    $self->{dbh}->do($drop_results);
    $self->init();
}

# ---------------------------------------------------------------------
# Retrieve execution times of all finished work items
# ---------------------------------------------------------------------
sub work_item_times {
    my $self = shift(@_);
    my $query = qq(
        SELECT s.work_item, s.worker_id, e.end_time - s.start_time
            FROM work_items AS s, results AS e
            WHERE s.work_item = e.work_item
            ORDER BY s.work_item;
    );
    return $self->{dbh}->selectall_arrayref($query);
}

# ---------------------------------------------------------------------
# Retrieve statistics on work item execution times
# ---------------------------------------------------------------------
sub work_item_stats {
    my $self = shift(@_);
    my $query = qq(
        SELECT COUNT(*),
               AVG(e.end_time - s.start_time),
               MIN(e.end_time - s.start_time),
               MAX(e.end_time - s.start_time)
            FROM work_items AS s, results AS e
            WHERE s.work_item = e.work_item;
    );
    return $self->{dbh}->selectall_arrayref($query);
}

# ---------------------------------------------------------------------
# Retrieve total execution time per worker
# ---------------------------------------------------------------------
sub worker_times {
    my $self = shift(@_);
    my $query = qq(
        SELECT s.worker_id, sum(e.end_time - s.start_time), count(*)
            FROM work_items AS s, results AS e
            WHERE s.work_item = e.work_item
            GROUP BY s.worker_id
            ORDER BY s.worker_id;
    );
    return $self->{dbh}->selectall_arrayref($query);
}

# ---------------------------------------------------------------------
# Retrieve statistics on workers
# ---------------------------------------------------------------------
sub worker_stats {
    my $self = shift(@_);
    my $query = qq(
        SELECT COUNT(t.worker_id),
               AVG(t.time),
               MIN(t.time),
               MAX(t.time)
            FROM (SELECT s.worker_id AS worker_id,
                         e.end_time - s.start_time AS time
                      FROM work_items AS s, results AS e
                      WHERE s.work_item = e.work_item
                      GROUP BY s.worker_id) AS t
    );
    return $self->{dbh}->selectall_arrayref($query);
}

# ---------------------------------------------------------------------
# Find failed work items only per worker
# ---------------------------------------------------------------------
sub worker_failed {
    my $self = shift(@_);
    my $query = qq(
        SELECT s.worker_id, count(*)
            FROM work_items AS s, results AS e
            WHERE s.work_item = e.work_item and e.exit_code <> 0
            GROUP BY s.worker_id
            ORDER BY s.worker_id;
    );
    return $self->{dbh}->selectall_arrayref($query);
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
        if ($line =~ /^(\d+)\s+(\w+)\s+by\s+(\d+)\s+at\s+(.+)/) {
            my $work_item = int($1);
            my $status = $2;
            my $worker_id = int($3);
            my $date = $4;
            my $exit_code = 0;
            if ($status eq 'failed') {
                if ($date =~ /(.+):\s+(\d+)$/) {
                    $date = $1;
                    $exit_code = int($2);
                } else {
                    croak("### error: unexpected format of log file");
                }
            }
            my $time = str2time($date);
            if ($status eq 'started') {
                $self->{start_insert_stmt}->execute($work_item, $worker_id,
                                                    $time);
            } else {
                $self->{end_insert_stmt}->execute($work_item, $exit_code,
                                                  $time);
            }
        }
    }
}

1;
