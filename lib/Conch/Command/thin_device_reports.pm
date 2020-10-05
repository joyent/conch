package Conch::Command::thin_device_reports;

=pod

=head1 NAME

thin_device_reports - remove unwanted device reports

=head1 SYNOPSIS

    bin/conch thin_device_reports [long options...]

        -n --dry-run            dry-run (no changes are made)
        --updated-since=<date>  only consider devices updated since <ISO8601 date>

        --help                  print usage message and exit

=cut

use Mojo::Base 'Mojolicious::Command', -signatures;
use Getopt::Long::Descriptive;
use Try::Tiny;
use Data::Page;

has description => 'remove unwanted device reports';

has usage => sub { shift->extract_usage };  # extracts from SYNOPSIS

has 'dry_run';

sub run ($self, @opts) {
    # if the user needs to ^C, print the post-processing statistics before exiting.
    local $SIG{INT} = sub {
        say "\naborting! We now have this many records:";
        $self->_print_stats;
        exit;
    };

    local @ARGV = @opts;
    my ($opt, $usage) = describe_options(
        # the descriptions aren't actually used anymore (mojo uses the synopsis instead)... but
        # the 'usage' text block can be accessed with $usage->text
        'thin_device_reports %o',
        [ 'dry-run|n',          'dry-run (no changes are made)' ],
        [ 'updated-since=s',    'updated-since=date (device update time' ],
        [],
        [ 'help',               'print usage message and exit', { shortcircuit => 1 } ],
    );

    $self->dry_run($opt->dry_run);

    say 'at start, we have this many records:';
    $self->_print_stats;

    # consider each device, oldest devices first, in pages of 100 rows each
    my $device_rs = ($self->dry_run ? $self->app->db_ro_devices : $self->app->db_devices)
        ->rows(100)
        ->page(1)
        ->order_by('created');

    $device_rs = $device_rs->search({ updated => { '>=', $opt->updated_since } }) if $opt->updated_since;

    my ($device_count, $device_reports_deleted, $validation_results_deleted) = (0)x3;

    foreach my $page (1 .. $device_rs->pager->last_page) {
        $device_rs = $device_rs->page($page);
        while (my $device = $device_rs->next) {
            # we process each device's reports in a separate transaction,
            # so we can abort and resume without redoing everything all over again
            try {
                my @deleted = $self->app->schema->txn_do(sub {
                    $self->_process_device($device);
                });
                ++$device_count;
                $device_reports_deleted += $deleted[0];
                $validation_results_deleted += $deleted[1];
            }
            catch {
                if (/Rollback failed/) {
                    local $@ = $_;
                    die;    # propagate the error
                }
                print STDERR "\n", 'aborted processing of device '.$device->id.': ', $_, "\n";
            };
        }
    }

    say "\n$device_count devices processed.";
    say $device_reports_deleted.' device_reports deleted.' if $device_reports_deleted;
    say $validation_results_deleted.' validation_results deleted.' if $validation_results_deleted;

    say 'at finish, we have this many records:';
    $self->_print_stats;
}

sub _print_stats ($self) {
    say 'device_report:           ', $self->app->db_ro_device_reports->count;
    say 'validation_state:        ', $self->app->db_ro_validation_states->count;
    say 'validation_state_member: ', $self->app->db_ro_validation_state_members->count;
    say 'validation_result:       ', $self->app->db_ro_validation_results->count;
}

sub _process_device ($self, $device) {
    my $report_count = 0;
    print 'device id ', $device->id, ': ';

    my $query = <<'SQL';
select id from (
  select
    device_report.id,
    device_report.created,
    coalesce(
      case when count(distinct(validation_state.status)) > 1 then 'NOT_UNIQUE'
          else min(validation_state.status)::text end,
      'NONE') as status,
    row_number() over (
      partition by device_report.device_id, status order by device_report.created desc
    ) as seq
  from device_report
  left join validation_state on validation_state.device_report_id = device_report.id
  group by device_report.id, device_report.created, status
) _tmp
where status != 'NOT_UNIQUE' and seq > 1 and created < (now() - interval '6 months')
SQL
    my $device_report_rs = $self->app->db_device_reports
        ->search({ 'device_report.device_id' => $device->id })
        ->search({ 'device_report.id' => => { -in => \[ $query ] } });

    my $device_reports_deleted = $device_report_rs->count;
    my $validation_results_deleted = 0;

    print "\n";

    if ($self->dry_run) {
        say 'Would delete ', $device_reports_deleted, ' reports for device id ', $device->id,
            ' out of ', $report_count, ' examined.';
    }
    else {
        # delete all reports that we identified for deletion
        # this may also cause cascade deletes on validation_state, validation_state_member.
        say 'deleting ', $device_reports_deleted, ' reports for device id ', $device->id,
            ' out of ', $report_count, ' examined...';

        $device_report_rs->delete;

        # delete all newly-orphaned validation_result rows for this device
        $validation_results_deleted = $device->delete_related('validation_results',
            { 'validation_state_members.validation_state_id' => undef },
            { join => 'validation_state_members' },
        );
    }

    print "\n";

    return ($device_reports_deleted, $validation_results_deleted);
}

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<https://www.mozilla.org/en-US/MPL/2.0/>.

=cut
# vim: set ts=4 sts=4 sw=4 et :
