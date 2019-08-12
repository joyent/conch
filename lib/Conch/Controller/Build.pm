package Conch::Controller::Build;

use Mojo::Base 'Mojolicious::Controller', -signatures;

use Conch::UUID 'is_uuid';

=pod

=head1 NAME

Conch::Controller::Build

=head1 METHODS

=head2 list

If the user is a system admin, retrieve a list of all builds in the database; otherwise,
limits the list to those build of which the user is a member.

Response uses the Builds json schema.

=cut

sub list ($c) {
    my $rs = $c->db_builds
        ->search({ 'user_build_roles.role' => 'admin' })
        ->prefetch([ { user_build_roles => 'user_account' }, 'completed_user' ])
        ->order_by([qw(build.name user_account.name)]);

    return $c->status(200, [ $rs->all ]) if $c->is_system_admin;

    # normal users can only see builds in which they are a member
    $rs = $rs->search({ 'build.id' => { -in =>
                $c->db_user_build_roles->search({ user_id => $c->stash('user_id') })
                ->get_column('build_id')->as_query
            } })
        if not $c->is_system_admin;

    $c->status(200, [ $rs->all ]);
}

=head2 create

Creates a build.

Requires the user to be a system admin.

=cut

sub create ($c) {
    my $input = $c->validate_request('BuildCreate');
    return if not $input;

    return $c->status(409, { error => 'a build already exists with that name' })
        if $c->db_builds->search({ $input->%{name} })->exists;

    # turn emails into user_ids, and confirm they all exist...
    # [ user_id|email, $value, $user_id ], [ ... ]
    my @admins = map [
        $_->%*,
       ($_->{user_id} && $c->db_user_accounts->search({ id => $_->{user_id} })->exists ? $_->{user_id}
      : $_->{email} ? $c->db_user_accounts->search_by_email($_->{email})->get_column('id')->single
      : undef)
    ], (delete $input->{admins})->@*;

    my @errors = map join(' ', $_->@[0,1]), grep !$_->[2], @admins;
    return $c->status(409, { error => 'unrecognized '.join(', ', @errors) }) if @errors;

    my $build = $c->db_builds->create({
        $input->%*,
        user_build_roles => [ map +{ user_id => $_->[2], role => 'admin' }, @admins ],
    });
    $c->log->info('created build '.$build->id.' ('.$build->name.')');
    $c->status(303, '/build/'.$build->id);
}

=head2 find_build

Chainable action that validates the C<build_id> or C<build_name> provided in the
path, and stashes the query to get to it in C<build_rs>.

If C<require_role> is provided, it is used as the minimum required role for the user to
continue; otherwise the user must be a system admin.

=cut

sub find_build ($c) {
    my $identifier = $c->stash('build_id_or_name');
    my $rs = $c->db_builds;
    if (is_uuid($identifier)) {
        $c->stash('build_id', $identifier);
        $rs = $rs->search({ 'build.id' => $identifier });
    }
    else {
        $c->stash('build_name', $identifier);
        $rs = $rs->search({ 'build.name' => $identifier });
    }

    return $c->status(404) if not $rs->exists;

    my $requires_role = $c->stash('require_role') // 'admin';
    if (not $c->is_system_admin
            and not $rs->user_has_role($c->stash('user_id'), $requires_role)) {
        $c->log->debug('User lacks the required role ('.$requires_role.') for build '.$identifier);
        return $c->status(403);
    }

    $c->stash('build_rs', $rs);
}

=head2 get

Get the details of a single build.
Requires the 'read-only' role on the build.

Response uses the Build json schema.

=cut

sub get ($c) {
    my ($build) = $c->stash('build_rs')
        ->search({ 'user_build_roles.role' => 'admin' })
        ->prefetch([ { user_build_roles => 'user_account' }, 'completed_user' ])
        ->order_by('user_account.name')
        ->all;
    $c->status(200, $build);
}

=head2 update

Modifies a build attribute: one or more of description, started, completed.
Requires the 'admin' role on the build.

=cut

sub update ($c) {
    my $input = $c->validate_request('BuildUpdate');
    return if not $input;

    my $build = $c->stash('build_rs')->single;
    my %old_columns = $build->get_columns;

    # set locally but do not save to db just yet
    $build->set_columns($input);

    return $c->status(409, { error => 'build cannot be completed before it is started' })
        if $build->completed and (not $build->started or $build->started > $build->completed);

    return $c->status(409, { error => 'build was already completed' })
        if $build->completed and $old_columns{completed};

    $c->log->info('build '.$build->id.' ('.$build->name.') started')
        if $build->started and not $old_columns{started};

    if (not $build->completed and $build->completed_user_id) {
        $build->completed_user_id(undef);
        $c->log->info('build '.$build->id.' ('.$build->name
            .') moved out of completed state');
    }
    elsif ($build->completed and not $build->completed_user_id) {
        $build->completed_user_id($c->stash('user')->id);
        my $users_updated = $build->search_related('user_build_roles', { role => 'rw' })
            ->update({ role => 'ro' });
        $c->log->info('build '.$build->id.' ('.$build->name
            .') completed; '.(0+$users_updated).' users had role converted from rw to ro');
    }

    $build->update if $build->is_changed;

    $c->status(303, '/build/'.$build->id);
}

=head2 list_users

Get a list of user members of the current build.
Requires the 'admin' role on the build.

Response uses the BuildUsers json schema.

=cut

sub list_users ($c) {
    my $rs = $c->stash('build_rs')
        ->related_resultset('user_build_roles')
        ->related_resultset('user_account')
        ->active
        ->columns([ { role => 'user_build_roles.role' }, map 'user_account.'.$_, qw(id name email) ])
        ->order_by([ { -desc => 'role' }, 'name' ]);

    $c->status(200, [ $rs->hri->all ]);
}

=head2 add_user

Adds a user to the current build, or upgrades an existing role entry to access the build.
Requires the 'admin' role on the build.

Optionally takes a query parameter C<send_mail> (defaulting to true), to send an email
to the user and to all build admins.

This endpoint is nearly identical to L<Conch::Controller::Organization/add_user>.

=cut

sub add_user ($c) {
    my $params = $c->validate_query_params('NotifyUsers');
    return if not $params;

    my $input = $c->validate_request('BuildAddUser');
    return if not $input;

    my $user_rs = $c->db_user_accounts->active;
    my $user = $input->{user_id} ? $user_rs->find($input->{user_id})
        : $input->{email} ? $user_rs->find_by_email($input->{email})
        : undef;
    return $c->status(404) if not $user;

    $c->stash('target_user', $user);
    my $build_name = $c->stash('build_name') // $c->stash('build_rs')->get_column('name')->single;

    # check if the user already has access to this build
    if (my $existing_role = $c->stash('build_rs')
            ->search_related('user_build_roles', { user_id => $user->id })->single) {
        if ($existing_role->role eq $input->{role}) {
            $c->log->debug('user '.$user->id.' ('.$user->name.') already has '.$input->{role}
                .' access to build '.$c->stash('build_id_or_name').': nothing to do');
            return $c->status(204);
        }

        $existing_role->update({ role => $input->{role} });
        $c->log->info('Updated access for user '.$user->id.' ('.$user->name.') in build '
            .$c->stash('build_id_or_name').' to the '.$input->{role}.' role');

        if ($params->{send_mail} // 1) {
            $c->send_mail(
                template_file => 'build_user_update_user',
                From => 'noreply@conch.joyent.us',
                Subject => 'Your Conch access has changed',
                build => $build_name,
                role => $input->{role},
            );
            my @admins = $c->stash('build_rs')
                ->admins('with_sysadmins')
                ->search({ 'user_account.id' => { '!=' => $user->id } });
            $c->send_mail(
                template_file => 'build_user_update_admins',
                To => $c->construct_address_list(@admins),
                From => 'noreply@conch.joyent.us',
                Subject => 'We modified a user\'s access to your build',
                build => $build_name,
                role => $input->{role},
            ) if @admins;
        }

        return $c->status(204);
    }

    $user->create_related('user_build_roles', {
        build_id => $c->stash('build_id') // $c->stash('build_rs')->get_column('id')->single,
        role => $input->{role},
    });
    $c->log->info('Added user '.$user->id.' ('.$user->name.') to build '.$c->stash('build_id_or_name').' with the '.$input->{role}.' role');

    if ($params->{send_mail} // 1) {
        $c->send_mail(
            template_file => 'build_user_add_user',
            From => 'noreply@conch.joyent.us',
            Subject => 'Your Conch access has changed',
            build => $build_name,
            role => $input->{role},
        );
        my @admins = $c->stash('build_rs')
            ->admins('with_sysadmins')
            ->search({ 'user_account.id' => { '!=' => $user->id } });
        $c->send_mail(
            template_file => 'build_user_add_admins',
            To => $c->construct_address_list(@admins),
            From => 'noreply@conch.joyent.us',
            Subject => 'We added a user to your build',
            build => $build_name,
            role => $input->{role},
        ) if @admins;
    }

    $c->status(204);
}

=head2 remove_user

Removes the indicated user from the build.
Requires the 'admin' role on the build.

Optionally takes a query parameter C<send_mail> (defaulting to true), to send an email
to the user and to all build admins.

This endpoint is nearly identical to L<Conch::Controller::Organization/remove_user>.

=cut

sub remove_user ($c) {
    my $params = $c->validate_query_params('NotifyUsers');
    return if not $params;

    my $user = $c->stash('target_user');
    my $rs = $c->stash('build_rs')
        ->search_related('user_build_roles', { user_id => $user->id });
    return $c->status(204) if not $rs->exists;

    return $c->status(409, { error => 'builds must have an admin' })
        if $rs->search({ role => 'admin' })->exists
            and $c->stash('build_rs')
                ->search_related('user_build_roles', { role => 'admin' })->count == 1;

    $c->log->info('removing user '.$user->id.' ('.$user->name.') from build '.$c->stash('build_id_or_name'));
    my $deleted = $rs->delete;

    if ($deleted > 0 and $params->{send_mail} // 1) {
        my $build_name = $c->stash('build_name') // $c->stash('build_rs')->get_column('name')->single;
        $c->send_mail(
            template_file => 'build_user_remove_user',
            From => 'noreply@conch.joyent.us',
            Subject => 'Your Conch builds have been updated',
            build => $build_name,
        );
        my @admins = $c->stash('build_rs')->admins('with_sysadmins');
        $c->send_mail(
            template_file => 'build_user_remove_admins',
            To => $c->construct_address_list(@admins),
            From => 'noreply@conch.joyent.us',
            Subject => 'We removed a user from your build',
            build => $build_name,
        ) if @admins;
    }

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
