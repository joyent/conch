package Conch::Controller::DatacenterRack;

use Mojo::Base 'Mojolicious::Controller', -signatures;

use Role::Tiny::With;
with 'Conch::Role::MojoLog';

use List::Util 'any';

=pod

=head1 NAME

Conch::Controller::DatacenterRack

=head1 METHODS

=head2 find_rack

Supports rack lookups by uuid.

=cut

sub find_rack ($c) {
    $c->log->debug('Looking for datacenter rack by id: '.$c->stash('datacenter_rack_id'));
    my $rack_rs = $c->db_datacenter_racks
        ->search({ 'datacenter_rack.id' => $c->stash('datacenter_rack_id') });

    if (not $rack_rs->exists) {
        $c->log->debug('Could not find datacenter rack ',$c->stash('datacenter_rack_id'));
        return $c->status(404 => { error => 'Not found' });
    }

    # HEAD, GET requires 'ro'; everything else (for now) requires 'rw'
    my $method = $c->req->method;
    my $requires_permission =
        (any { $method eq $_ } qw(HEAD GET)) ? 'ro'
      : (any { $method eq $_ } qw(POST PUT DELETE)) ? 'rw'
      : die "need handling for $method method";

    if (not $rack_rs->user_has_permission($c->stash('user_id'), $requires_permission)) {
        $c->log->debug('User lacks permission to access rack'.$c->stash('datacenter_rack_id'));
        return $c->status(403, { error => 'Forbidden' });
    }

    $c->log->debug('Found datacenter rack '.$c->stash('datacenter_rack_id'));
    my $rack = $rack_rs->single;
    $c->stash('rack' => $rack);
    return 1;
}

=head2 create

Stores data as a new datacenter_rack row, munging 'role' to 'datacenter_rack_role_id'.

=cut

sub create ($c) {
    return $c->status(403) unless $c->is_system_admin;
    my $input = $c->validate_input('RackCreate');
    return if not $input;

    unless ($c->db_datacenter_rooms->search({ id => $input->{datacenter_room_id} })->exists) {
        return $c->status(400 => { error => 'Room does not exist' });
    }

    unless ($c->db_datacenter_rack_roles->search({ id => $input->{role} })->exists) {
        return $c->status(400 => { error => 'Rack role does not exist' });
    }

    $input->{datacenter_rack_role_id} = delete $input->{role};

    my $rack = $c->db_datacenter_racks->create($input);
    $c->log->debug('Created datacenter rack '.$rack->id);

    $c->status(303 => '/rack/'.$rack->id);
}

=head2 get

Get a single rack

Response uses the Rack json schema.

=cut

sub get ($c) {
    $c->status(200, $c->stash('rack'));
}

=head2 get_all

Get all racks

Response uses the Racks json schema.

=cut

sub get_all ($c) {
    # TODO: instead of sysadmin privs, filter out results by workspace permissions
    return $c->status(403) unless $c->is_system_admin;

    my @racks = $c->db_datacenter_racks->all;
    $c->log->debug('Found '.scalar(@racks).' datacenter racks');

    $c->status(200, \@racks);
}

=head2 layouts

Gets all the layouts for the specified rack.

Response uses the RackLayouts json schema.

=cut

sub layouts ($c) {
    # TODO: to be more helpful to the UI, we should include the width of the hardware that will
    # occupy each rack_unit(s).

    my @layouts = $c->stash('rack')
        ->related_resultset('datacenter_rack_layouts')
        #->search(undef, {
        #    join => { 'hardware_product' => 'hardware_product_profile' },
        #    '+columns' => { rack_unit_size =>  'hardware_product_profile.rack_unit' },
        #    collapse => 1,
        #})
        ->order_by([ qw(rack_unit_start) ])
        ->all;

    $c->log->debug('Found '.scalar(@layouts).' datacenter rack layouts');
    $c->status(200 => \@layouts);
}

=head2 update

Update an existing rack.

=cut

sub update ($c) {
    my $input = $c->validate_input('RackUpdate');
    return if not $input;

    if ($input->{datacenter_room_id}
            and $input->{datacenter_room_id} ne $c->stash('rack')->datacenter_room_id) {
        unless ($c->db_datacenter_rooms->search({ id => $input->{datacenter_room_id} })->exists) {
            return $c->status(400 => { error => 'Room does not exist' });
        }
    }

    # prohibit shrinking rack_size if there are layouts that extend beyond it
    if (exists $input->{role} and $input->{role} ne $c->stash('rack')->datacenter_rack_role_id) {
        my $rack_role = $c->db_datacenter_rack_roles->find($input->{role});
        if (not $rack_role) {
            return $c->status(400 => { error => 'Rack role does not exist' });
        }

        my %assigned_rack_units = map { $_ => 1 }
            $c->stash('rack')->self_rs->assigned_rack_units;
        my @assigned_rack_units = sort { $a <=> $b } keys %assigned_rack_units;

        if (my @out_of_range = grep { $_ > $rack_role->rack_size } @assigned_rack_units) {
            $c->log->debug('found layout used by rack id '.$c->stash('rack')->id
                .' that has assigned rack_units greater requested new rack_size of '
                .$rack_role->rack_size.': ', join(', ', @out_of_range));
            return $c->status(400 => { error => 'cannot resize rack: found an assigned rack layout that extends beyond the new rack_size' });
        }

        $input->{datacenter_rack_role_id} = delete $input->{role};
    }

    $c->stash('rack')->update($input);
    $c->log->debug('Updated datacenter rack '.$c->stash('rack')->id);
    return $c->status(303 => '/rack/'.$c->stash('rack')->id);
}

=head2 delete

Delete a rack.

=cut

sub delete ($c) {
    if ($c->stash('rack')->related_resultset('datacenter_rack_layouts')->exists) {
        $c->log->debug('Cannot delete datacenter_rack: in use by one or more datacenter_rack_layouts');
        return $c->status(400 => { error => 'cannot delete a datacenter_rack when a detacenter_rack_layout is referencing it' });
    }

    $c->stash('rack')->delete;
    $c->log->debug('Deleted datacenter rack '.$c->stash('rack')->id);
    return $c->status(204);
}

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut
# vim: set ts=4 sts=4 sw=4 et :
