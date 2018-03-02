=pod

=head1 NAME

Conch::Controller::WorkspaceUser

=head1 METHODS

=cut

package Conch::Controller::WorkspaceUser;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Printer;

use Conch::Models;
use Conch::Pg;


=head2 list

Get a list of users for the current stashed C<current_workspace>

=cut

sub list ($c) {
	my $users = Conch::Model::WorkspaceUser->new->workspace_users(
		$c->stash('current_workspace')->id 
	);
	$c->status( 200, [ map { $_->as_v1_json } @$users ] );
}


=head2 invite

Invite a user to the current stashed C<current_workspace>

=cut

sub invite ($c) {
	my $body = $c->req->json;
	return $c->status( 400, { error => '"user" and "role " fields required ' } )
		unless ( $body->{user} and $body->{role} );

	return $c->status(403) if $c->stash('current_workspace')->role eq 'Read-only';
	return $c->status(403) if $c->stash('current_workspace')->role eq 'Integrator';

	my $ws         = $c->stash('current_workspace');
	my $maybe_role = $c->role->lookup_by_name( $body->{role} );

	unless ( $maybe_role ) {
		my $role_names = join( ', ', map { $_->name } @{ $c->role->list() } );
		return $c->status( 400,
			{ error => '"role" must be one of: ' . $role_names } );
	}

	my $user = Conch::Model::User->lookup_by_email(
		Conch::Pg->new(),
		$body->{user}
	);

	if ($user) {
		$c->mail->send_existing_user_invite(
			{
				email          => $user->email,
				workspace_name => $ws->name
			}
		);
	}
	else {
		my $password = $c->random_string( length => 10 );
		$user = Conch::Model::User->create(
			Conch::Pg->new(),
			$body->{user},
			$password
		);
		$c->mail->send_new_user_invite(
			{ email => $user->email, password => $password } );
	}

	Conch::Model::Workspace->new->add_user_to_workspace(
		$user->id,
		$ws->id,
		$maybe_role->id
	);
	$c->status(201);
}

1;


__DATA__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License, 
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut

