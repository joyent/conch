package Conch::Controller::Relay;

use Mojo::Base 'Mojolicious::Controller', -signatures;

=pod

=head1 NAME

Conch::Controller::Relay

=head1 METHODS

=head2 register

Registers a relay and connects it with the current user. The relay is created
it if the relay does not already exists

=cut

sub register ($c) {
    my $input = $c->validate_input('RegisterRelay');
    return if not $input;

    return $c->status(422, { error => 'serial number in path doesn\'t match payload data' })
        if $c->stash('relay_id') ne $input->{serial};


    my $relay = $c->db_relays->update_or_create({
        id => delete $input->{serial},
        $input->%*,
        updated    => \'now()',
        deactivated => undef,
    });

    $relay->update_or_create_related('user_relay_connections', {
        user_id => $c->stash('user_id'),
        last_seen => \'now()',
    });

    $c->status(204);
}

=head2 list

If the user is a system admin, retrieve a list of all active relays in the database

Response uses the Relays json schema.

=cut

sub list ($c) {
    return $c->status(403) if not $c->is_system_admin;
    $c->status(200, [ $c->db_relays->active->all ]);
}

=head2 delete

=cut

sub delete ($c) {
    my $identifier = $c->stash('relay_serial_number');

    my $rs = $c->db_relays
        ->active
        ->search({ id => $identifier });
    return $c->status(404) if not $rs->exists;

    my $drc_count = $rs->related_resultset('device_relay_connections')->delete;
    my $urc_count = $rs->related_resultset('user_relay_connections')->delete;
    $rs->deactivate;

    $c->log->debug('Deactivated relay '.$identifier
        .', removing '.$drc_count.' associated device connections and '
        .$urc_count.' associated user connections');
    return $c->status(204);
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
