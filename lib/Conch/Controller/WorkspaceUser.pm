=pod

=head1 NAME

Conch::Controller::WorkspaceUser

=head1 METHODS

=cut

package Conch::Controller::WorkspaceUser;

use Role::Tiny::With;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Data::Printer;
use List::Util 1.33 qw(none any);

with 'Conch::Role::MojoLog';

=head2 list

Get a list of users for the current workspace
Returns a listref of hashrefs with keys: name, email, role.
TODO: include id?

=cut

sub list ($c) {
	my $users = [
		map {
			my $uwr = $_;
			+{
				(map { $_ => $uwr->user_account->$_ } qw(name email)),
				role => $uwr->role,
			}
		} $c->db_user_workspace_roles->search(
			{ workspace_id => $c->stash('workspace_id') },
			{ prefetch => 'user_account' },
		)->all
	];

	$c->log->debug("Found ".scalar($users->@*)." users");
	$c->status( 200, $users );
}

=head2 invite

Invite a user to the current workspace (as specified by :workspace_id in the path)

Optionally takes a query parameter 'send_invite_mail' (defaulting to true), to send an email
to the user.

=cut

sub invite ($c) {
	my $body = $c->req->json;
	return $c->status(403) unless $c->is_admin;

	unless($body->{user} and $body->{role}) {
		# FIXME actually use the validator
		$c->log->warn("Input failed validation");
		return $c->status( 400, { 
			error => '"user" and "role " fields required'
		});
	}

	my @role_names = Conch::DB::Result::UserWorkspaceRole->column_info('role')->{extra}{list}->@*;
	if (none { $body->{role} eq $_ } @role_names) {
		my $role_names = join( ', ', @role_names);

		$c->log->debug("Role name '".$body->{role}."' was not one of $role_names");
		return $c->status( 400 => {
				error => '"role" must be one of: ' . $role_names 
		});
	}

	# TODO: it would be nice to be sure of which type of data we were being passed here, so we
	# don't have to look up by multiple columns.
	my $rs = $c->db_user_accounts->search(undef, { prefetch => 'user_workspace_roles' });
	my $user = $rs->lookup_by_email($body->{user}) || $rs->lookup_by_name($body->{user});

	unless ($user) {
		$c->log->debug("User '".$body->{user}."' was not found");

		my $password = $c->random_string();
		$user = $c->db_user_accounts->create({
			email    => $body->{user},
			name     => $body->{user}, # FIXME: we should always have a name.
			password => $password,     # will be hashed in constructor
		});

		$c->log->info("User '".$body->{user}."' was created with ID ".$user->id);
		if ($c->req->query_params->param('send_invite_mail') // 1) {
			$c->log->info('sending new user invite mail to user ' . $user->name);
			$c->send_mail(new_user_invite => {
				name	=> $user->name,
				email	=> $user->email,
				password => $password,
			});
		}

		# TODO update this complain when we stop sending plaintext passwords
		$c->log->warn("Email sent to ".$user->email." containing their PLAINTEXT password");
	}

	# FIXME! do not downgrade a user's existing access to this workspace.
	my $workspace_id = $c->stash('workspace_id');
	$user->create_related('user_workspace_roles' => {
		workspace_id => $workspace_id,
		role => $body->{role},
	}) if not any { $_->workspace_id eq $workspace_id } $user->user_workspace_roles;

	$c->log->info("Add user ".$user->id." to workspace $workspace_id");
	$c->status(201);
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
