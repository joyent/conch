package Conch::DB::ResultSet::Device;
use v5.26;
use warnings;
use parent 'Conch::DB::ResultSet';

use experimental 'signatures';
use Carp ();
use List::Util 'none';

=head1 NAME

Conch::DB::ResultSet::Device

=head1 DESCRIPTION

Interface to queries involving devices.

=head1 METHODS

=head2 user_has_role

Checks that the provided user_id has (at least) the specified role in at least one
workspace associated with the specified device(s), including parent workspaces.

=cut

sub user_has_role ($self, $user_id, $role) {
    Carp::croak('role must be one of: ro, rw, admin')
        if none { $role eq $_ } qw(ro rw admin);

    my $device_workspaces_ids_rs = $self
        ->related_resultset('device_location')
        ->related_resultset('rack')
        ->related_resultset('workspace_racks')
        ->related_resultset('workspace')
        ->distinct
        ->get_column('id');

    $self->result_source->schema->resultset('workspace')
        ->and_workspaces_above($device_workspaces_ids_rs)
        ->related_resultset('user_workspace_roles')
        ->user_has_role($user_id, $role);
}

=head2 devices_without_location

Restrict results to those that do not have a registered location.

=cut

sub devices_without_location ($self) {
    $self->search(
        { 'device_location.rack_id' => undef },
        { join => 'device_location' },
    );
}

=head2 latest_device_report

Returns a resultset that finds the most recent device report matching the device(s). This is
not a window function, so only one report is returned for all matching devices, not one report
per device! (We probably never need to do the latter. *)

* but if we did, you'd want something like:

    $self->search(undef, {
        '+columns' => {
            $col => $self->correlate('device_reports')
                ->columns($col)
                ->order_by({ -desc => 'device_reports.created' })
                ->rows(1)
                ->as_query
        },
    });

=cut

sub latest_device_report ($self) {
    $self->related_resultset('device_reports')
        ->order_by({ -desc => 'device_reports.created' })
        ->rows(1);
}

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<http://mozilla.org/MPL/2.0/>.

=cut
# vim: set ts=4 sts=4 sw=4 et :
