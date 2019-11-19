package Conch::Controller::Rack;

use Mojo::Base 'Mojolicious::Controller', -signatures;

use List::Util qw(any none first uniq);

=pod

=head1 NAME

Conch::Controller::Rack

=head1 METHODS

=head2 find_rack

Supports rack lookups by uuid.

=cut

sub find_rack ($c) {
    $c->log->debug('Looking for rack by id: '.$c->stash('rack_id'));
    my $rack_rs = $c->db_racks
        ->search({ 'rack.id' => $c->stash('rack_id') });

    if (not $rack_rs->exists) {
        $c->log->debug('Could not find rack ',$c->stash('rack_id'));
        return $c->status(404);
    }

    # HEAD, GET requires 'ro'; everything else (for now) requires 'rw'
    my $method = $c->req->method;
    my $requires_permission =
        (any { $method eq $_ } qw(HEAD GET)) ? 'ro'
      : (any { $method eq $_ } qw(POST PUT DELETE)) ? 'rw'
      : die 'need handling for '.$method.' method';

    if (not $rack_rs->user_has_permission($c->stash('user_id'), $requires_permission)) {
        $c->log->debug('User lacks permission to access rack'.$c->stash('rack_id'));
        return $c->status(403);
    }

    $c->log->debug('Found rack '.$c->stash('rack_id'));
    $c->stash('rack_rs', $rack_rs);
    return 1;
}

=head2 create

Stores data as a new rack row, munging 'role' to 'rack_role_id'.

=cut

sub create ($c) {
    return $c->status(403) if not $c->is_system_admin;

    my $input = $c->validate_input('RackCreate');
    return if not $input;

    if (not $c->db_datacenter_rooms->search({ id => $input->{datacenter_room_id} })->exists) {
        return $c->status(400, { error => 'Room does not exist' });
    }

    if (not $c->db_rack_roles->search({ id => $input->{role} })->exists) {
        return $c->status(400, { error => 'Rack role does not exist' });
    }

    if ($c->db_racks->search({ datacenter_room_id => $input->{datacenter_room_id}, name => $input->{name} })->exists) {
        return $c->status(409, { error => 'The room already contains a rack named '.$input->{name} });
    }

    $input->{rack_role_id} = delete $input->{role};

    my $rack = $c->db_racks->create($input);
    $c->log->debug('Created rack '.$rack->id);

    $c->status(303, '/rack/'.$rack->id);
}

=head2 get

Get a single rack

Response uses the Rack json schema.

=cut

sub get ($c) {
    $c->status(200, $c->stash('rack_rs')->single);
}

=head2 get_all

Get all racks

Response uses the Racks json schema.

=cut

sub get_all ($c) {
    # TODO: instead of sysadmin privs, filter out results by workspace permissions
    return $c->status(403) if not $c->is_system_admin;

    my @racks = $c->db_racks->all;
    $c->log->debug('Found '.scalar(@racks).' racks');

    $c->status(200, \@racks);
}

=head2 layouts

Gets all the layouts for the specified rack.

Response uses the RackLayouts json schema.

=cut

sub layouts ($c) {
    # TODO: to be more helpful to the UI, we should include the width of the hardware that will
    # occupy each rack_unit(s).

    my @layouts = $c->stash('rack_rs')
        ->related_resultset('rack_layouts')
        #->search(undef, {
        #    join => { hardware_product => 'hardware_product_profile' },
        #    '+columns' => { rack_unit_size =>  'hardware_product_profile.rack_unit' },
        #    collapse => 1,
        #})
        ->order_by('rack_unit_start')
        ->all;

    $c->log->debug('Found '.scalar(@layouts).' rack layouts');
    $c->status(200, \@layouts);
}

=head2 update

Update an existing rack.

=cut

sub update ($c) {
    my $input = $c->validate_input('RackUpdate');
    return if not $input;

    my $rack_rs = $c->stash('rack_rs');
    my $rack = $rack_rs->single;

    if ($input->{datacenter_room_id} and $input->{datacenter_room_id} ne $rack->datacenter_room_id) {
        if (not $c->db_datacenter_rooms->search({ id => $input->{datacenter_room_id} })->exists) {
            return $c->status(400, { error => 'Room does not exist' });
        }

        if ($c->db_racks->search({ datacenter_room_id => $input->{datacenter_room_id}, name => $input->{name} // $rack->name })->exists) {
            return $c->status(409, { error => 'New room already contains a rack named '.($input->{name} // $rack->name) });
        }
    }
    elsif ($input->{name} and $input->{name} ne $rack->name) {
        if ($c->db_racks->search({ datacenter_room_id => $rack->datacenter_room_id, name => $input->{name} })->exists) {
            return $c->status(409, { error => 'The room already contains a rack named '.($input->{name} // $rack->name) });
        }
    }

    # prohibit shrinking rack_size if there are layouts that extend beyond it
    if (exists $input->{role}
            and ($input->{rack_role_id} = delete $input->{role}) ne $rack->rack_role_id) {
        my $rack_role = $c->db_rack_roles->find($input->{rack_role_id});
        if (not $rack_role) {
            return $c->status(400, { error => 'Rack role does not exist' });
        }

        my @assigned_rack_units = $rack_rs->assigned_rack_units;

        if (my @out_of_range = grep $_ > $rack_role->rack_size, @assigned_rack_units) {
            $c->log->debug('found layout used by rack id '.$c->stash('rack_id')
                .' that has assigned rack_units greater requested new rack_size of '
                .$rack_role->rack_size.': ', join(', ', @out_of_range));
            return $c->status(400, { error => 'cannot resize rack: found an assigned rack layout that extends beyond the new rack_size' });
        }
    }

    $rack->set_columns($input);
    $rack->update({ updated => \'now()' }) if $rack->is_changed;
    $c->log->debug('Updated rack '.$rack->id);
    return $c->status(303, '/rack/'.$rack->id);
}

=head2 delete

Delete a rack.

=cut

sub delete ($c) {
    if ($c->stash('rack_rs')->related_resultset('rack_layouts')->exists) {
        $c->log->debug('Cannot delete rack: in use by one or more rack_layouts');
        return $c->status(400, { error => 'cannot delete a rack when a rack_layout is referencing it' });
    }

    # deletions will cascade to workspace_rack.
    $c->stash('rack_rs')->delete;
    $c->log->debug('Deleted rack '.$c->stash('rack_id'));
    return $c->status(204);
}

=head2 get_assignment

Gets all the rack layout assignments (including occupying devices) for the specified rack.

Response uses the RackAssignments json schema.

=cut

sub get_assignment ($c) {
    my @assignments = $c->stash('rack_rs')
        ->related_resultset('rack_layouts')
        ->columns([ 'rack_unit_start' ])
        ->search(undef, {
            join => [
                { device_location => 'device' },
                { hardware_product => 'hardware_product_profile' },
            ],
            '+columns' => {
                device_id => 'device.id',
                device_asset_tag => 'device.asset_tag',
                hardware_product => 'hardware_product.name',
                # TODO: this should be renamed in the db itself.
                rack_unit_size =>  'hardware_product_profile.rack_unit',
            },
            collapse => 1,
        })
        ->order_by('rack_unit_start')
        ->hri
        ->all;

    $c->log->debug('Found '.scalar(@assignments).' device-rack assignments');
    $c->status(200, \@assignments);
}

=head2 set_assignment

Assigns devices to rack layouts, also optionally updating asset_tags.
Existing devices in referenced slots will be removed as needed.

=cut

sub set_assignment ($c) {
    my $input = $c->validate_input('RackAssignmentUpdates');
    return if not $input;

    return $c->status(400, { error => 'duplication of device_ids is not permitted' })
        if (uniq map $_->{device_id}, $input->@*) != $input->@*;
    return $c->status(400, { error => 'duplication of rack_unit_starts is not permitted' })
        if (uniq map $_->{rack_unit_start}, $input->@*) != $input->@*;

    my @layouts = $c->stash('rack_rs')->search_related('rack_layouts',
            { 'rack_layouts.rack_unit_start' => { -in => [ map $_->{rack_unit_start}, $input->@* ] } })
        ->prefetch('device_location')
        ->order_by('rack_layouts.rack_unit_start');

    if (@layouts != $input->@*) {
        my @missing = grep {
            my $ru = $_;
            none { $ru == $_->rack_unit_start } @layouts;
        } map $_->{rack_unit_start}, $input->@*;
        return $c->status(400, { error => 'missing layout'.(@missing > 1 ? 's' : '').' for rack_unit_start '.join(', ', @missing) });
    }

    my %devices = map +($_->id => $_),
        $c->db_devices->search({ id => { -in => [ map $_->{device_id}, $input->@* ] } });

    my $device_locations_rs = $c->stash('rack_rs')->related_resultset('device_locations');

    $c->txn_wrapper(sub ($c) {
        foreach my $entry ($input->@*) {
            my $layout = first { $_->rack_unit_start == $entry->{rack_unit_start} } @layouts;
            if (my $device = $devices{$entry->{device_id}}) {
                if (exists $entry->{device_asset_tag}) {
                    $device->asset_tag($entry->{device_asset_tag});
                    $device->update({ updated => \'now()' }) if $device->is_changed;
                }
                # we'll allow this as it will be caught by a validation later on,
                # but it's probably user error of some kind.
                $c->log->warn('locating device id '.$device->id
                        .' in slot with incorrect hardware: expecting hardware_product_id '
                        .$layout->hardware_product_id.', but instead it has hardware_product_id '
                        .$device->hardware_product_id)
                    if $device->hardware_product_id ne $layout->hardware_product_id;
            }
            else {
                my $device = $c->db_devices->create({
                    id => $entry->{device_id},
                    asset_tag => $entry->{device_asset_tag},
                    hardware_product_id => $layout->hardware_product_id,
                    health => 'unknown',
                    state => 'UNKNOWN',
                });
            }

            next if $device_locations_rs->search({ $entry->%{qw(device_id rack_unit_start)} })->exists;

            # remove current occupant, if it exists
            # (TODO: with deferred constraints, if it is moving to another slot we should not delete)
            $device_locations_rs->search({ rack_unit_start => $entry->{rack_unit_start} })->delete;

            $c->db_device_locations->update_or_create(
                {
                    rack_id => $c->stash('rack_id'),
                    $entry->%{qw(device_id rack_unit_start)},
                    updated => \'now()',
                },
                { key => 'primary' },   # only search for conflicts by device_id
            );
        }
        return 1;
    })
    or return $c->status(400);

    $c->log->debug('Updated device assignments for rack '.$c->stash('rack_id'));
    $c->status(303, '/rack/'.$c->stash('rack_id').'/assignment');
}

=head2 delete_assignment

=cut

sub delete_assignment ($c) {
    my $input = $c->validate_input('RackAssignmentDeletes');
    return if not $input;

    my @layouts = $c->stash('rack_rs')->search_related('rack_layouts',
            { 'rack_layouts.rack_unit_start' => { -in => [ map $_->{rack_unit_start}, $input->@* ] } })
        ->prefetch('device_location')
        ->order_by('rack_layouts.rack_unit_start');

    if (@layouts != $input->@*) {
        my @missing = grep {
            my $ru = $_;
            none { $ru == $_->rack_unit_start } @layouts;
        } map $_->{rack_unit_start}, $input->@*;
        $c->log->debug('cannot delete nonexistent layout'.(@missing > 1 ? 's' : '').' for rack_unit_start '.join(', ', @missing));
        return $c->status(404);
    }

    if (my @unoccupied = grep !$_->device_location, @layouts) {
        $c->log->debug('cannot delete assignments for unoccupied slot'.
            (@unoccupied > 1 ? 's' : '').': rack_unit_start '
            .join(', ', map $_->rack_unit_start, @unoccupied));
        return $c->status(404);
    }

    foreach my $entry ($input->@*) {
        my $layout = first { $_->rack_unit_start == $entry->{rack_unit_start} } @layouts;
        if ($layout->device_location->device_id ne $entry->{device_id}) {
            $c->log->debug('rack_unit_start '.$layout->rack_unit_start
                .' occupied by device_id '.$layout->device_location->device_id
                .' but was expecting device_id '.$entry->{device_id});
            $c->status(404);
        }
    }

    return if $c->res->code;

    my $deleted = $c->stash('rack_rs')->search_related('rack_layouts',
            { 'rack_layouts.rack_unit_start' => { -in => [ map $_->{rack_unit_start}, $input->@* ] } })
        ->related_resultset('device_location')
        ->delete;

    $c->log->debug('deleted '.$deleted.' device-rack assignment'.($deleted > 1 ? 's' : ''));

    return $c->status(204);
}

=head2 set_phase

Updates the phase of this rack, and optionally all devices located in this rack.

Use the C<rack_only> query parameter to specify whether to only update the rack's phase, or all
located devices' phases as well.

=cut

sub set_phase ($c) {
    my $input = $c->validate_input('RackPhase');
    return if not $input;

    $c->stash('rack_rs')->update({ phase => $input->{phase}, updated => \'now()' });
    $c->log->debug('set the phase for rack '.$c->stash('rack_id').' to '.$input->{phase});

    if (not $c->req->query_params->param('rack_only') // 0) {
        $c->stash('rack_rs')
            ->related_resultset('device_locations')
            ->related_resultset('device')
            ->update({ phase => $input->{phase}, updated => \'now()' });

        $c->log->debug('set the phase for all devices in rack '.$c->stash('rack_id').' to '.$input->{phase});
    }

    $c->status(303, '/rack/'.$c->stash('rack_id'));
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
