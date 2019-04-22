package Conch::Controller::User;

use Mojo::Base 'Mojolicious::Controller', -signatures;

use Role::Tiny::With;
with 'Conch::Role::MojoLog';

use Mojo::Exception;
use List::Util 'pairmap';
use Mojo::JSON qw(to_json from_json);
use Conch::UUID 'is_uuid';
use Email::Valid;

=pod

=head1 NAME

Conch::Controller::User

=head1 METHODS

=head2 revoke_own_tokens

Revoke the user's own session tokens.
B<NOTE>: This will cause the next request to fail authentication.

=cut

sub revoke_own_tokens ($c) {
	$c->log->debug('revoking user token for user ' . $c->stash('user')->name . ' at their request');
	$c->stash('user')->delete_related('user_session_tokens');
	$c->status(204);
}

=head2 revoke_user_tokens

Revoke a specified user's session tokens. System admin only.

=cut

sub revoke_user_tokens ($c) {
	my $user = $c->stash('target_user');

	$c->log->debug('revoking session tokens for user ' . $user->name . ', forcing them to /login again');
	$user->delete_related('user_session_tokens');
	$user->update({ refuse_session_auth => 1 });

	$c->status(204);
}

=head2 set_settings

Override the settings for a user with the provided payload

=cut

sub set_settings ($c) {
	my $body = $c->req->json;
	return $c->status( 400, { error => 'Payload required' } ) unless $body;

	my $user = $c->stash('user');
	Mojo::Exception->throw('Could not find previously stashed user')
		unless $user;

	# deactivate *all* settings first
	$user->related_resultset('user_settings')->active->deactivate;

	# store new settings
	$user->related_resultset('user_settings')
		->populate([ pairmap { +{ name => $a, value => to_json($b) } } $body->%* ]);

	$c->status(200);
}

=head2 set_setting

Set the value of a single setting for the user

FIXME: the key name is repeated in the URL and the payload :(

=cut

sub set_setting ($c) {
	my $body  = $c->req->json;
	my $key   = $c->stash('key');
	my $value = $body->{$key};
	return $c->status(
		400,
		{
			error =>
				"Setting key in request object must match name in the URL ('$key')"
		}
	) unless $value;

	my $user = $c->stash('user');
	Mojo::Exception->throw('Could not find previously stashed user')
		unless $user;

	# FIXME? we should have a unique constraint on user_id+name
	# rather than creating additional rows.

	$user->search_related('user_settings', { name => $key })->active->deactivate;

	my $setting = $user->create_related('user_settings', {
		name => $key,
		value => to_json($value),
	});

	if ($setting) {
		return $c->status(200);
	}
	else {
		return $c->status( 500, "Failed to set setting" );
	}
}

=head2 get_settings

Get the key/values of every setting for a User

=cut

sub get_settings ($c) {
	my $user = $c->stash('user');
	Mojo::Exception->throw('Could not find previously stashed user')
		unless $user;

	# turn user_setting db rows into name => value entries,
	# newer entries overwriting older ones
	my %output = map {
		$_->name => from_json($_->value)
	} $user->user_settings->active->search(undef, { order_by => 'created' });

	$c->status( 200, \%output );
}

=head2 get_setting

Get the individual key/value pair for a setting for the User

=cut

sub get_setting ($c) {
	my $key = $c->stash('key');

	my $user = $c->stash('user');
	Mojo::Exception->throw('Could not find previously stashed user')
		unless $user;

	my $setting = $user->user_settings->active->search(
		{ name => $key },
		{ order_by => { -desc => 'created' } },
	)->one_row;

	return $c->status(404) unless $setting;

	$c->status( 200, { $key => from_json($setting->value) } );
}

=head2 delete_setting

Delete a single setting for a user, provided it was set previously

=cut

sub delete_setting ($c) {
	my $key = $c->stash('key');

	my $user = $c->stash('user');
	Mojo::Exception->throw('Could not find previously stashed user')
		unless $user;

	my $count = $user->search_related('user_settings', { name => $key })->active->deactivate;

	return $c->status(404) unless $count;

	return $c->status(204);
}

=head2 change_own_password

Stores a new password for the current user.

Optionally takes a query parameter 'clear_tokens' (defaulting to true), to also revoke session
tokens for the user, forcing all tools to log in again.

=cut

sub change_own_password ($c) {
	my $body =  $c->validate_input('UserPassword');
	return if not $body;

	my $new_password = $body->{password};

	my $user = $c->stash('user');
	Mojo::Exception->throw('Could not find previously stashed user')
		unless $user;

	$user->update({
		password => $new_password,
		refuse_session_auth => 0,
		force_password_change => 0,
	});

	$c->log->debug('updated password for user ' . $user->name . ' at their request');

	return $c->status(204)
		unless $c->req->query_params->param('clear_tokens') // 1;

	$c->stash('user')->delete_related('user_session_tokens');

	# processing continues with Conch::Controller::Login::session_logout
	return 1;
}

=head2 reset_user_password

Generates a new random password for a user. System admin only.

Optionally takes a query parameter 'send_password_reset_mail' (defaulting to true), to send an
email to the user with the new password.

Optionally takes a query parameter 'clear_tokens' (defaulting to true), to also revoke session
tokens for the user, forcing all their tools to log in again. The user must also change their
password after logging in, as they will not be able to log in with it again.

=cut

sub reset_user_password ($c) {
	my $user = $c->stash('target_user');

	my %update = (
		password => $c->random_string(),
	);

	if ($c->req->query_params->param('clear_tokens') // 1) {
		$c->log->warn('user ' . $c->stash('user')->name . ' deleting user session tokens for user ' . $user->name);
		$user->delete_related('user_session_tokens');

		%update = (
			%update,

			# subsequent attempts to authenticate with the browser session or JWT will return
			# 401 unauthorized, except for the /user/me/password endpoint
			refuse_session_auth => 1,

			# the next /login access will result in another password reset,
			# a reminder to the user to change their password,
			# and the session expiration will be reduced to 10 min
			force_password_change => 1,
		);
	}

	$c->log->warn('user ' . $c->stash('user')->name . ' resetting password for user ' . $user->name);
	$user->update({ %update });

	return $c->status(204) if not $c->req->query_params->param('send_password_reset_mail') // 1;

	$c->log->info('sending "password was changed" mail to user ' . $user->name);
	$c->send_mail(changed_user_password => {
		name     => $user->name,
		email    => $user->email,
		password => $update{password},
	});
	return $c->status(202);
}

=head2 find_user

Chainable action that validates the user_id or email address (prefaced with 'email=') provided
in the path, and stashes the corresponding user row in C<target_user>.

=cut

sub find_user ($c) {
	my $user_param = $c->stash('target_user_id');

	return $c->status(400, { error => 'invalid identifier format for '.$user_param })
		if not is_uuid($user_param)
			and not ($user_param =~ /^email\=/ and Email::Valid->address($'));

	my $user_rs = $c->db_user_accounts;

	# when deactivating users or removing users from a workspace, we want to find
	# already-deactivated users too.
	$user_rs = $user_rs->active if $c->req->method ne 'DELETE';

	$c->log->debug('looking up user '.$user_param);
	my $user = $user_rs->lookup_by_id_or_email($user_param);

	return $c->status(404) if not $user;

	$c->stash('target_user', $user);
	return 1;
}

=head2 get

Gets information about a user. System admin only.
Response uses the UserDetailed json schema.

=cut

sub get ($c) {
	my $user = $c->stash('target_user')
		->discard_changes({ prefetch => { user_workspace_roles => 'workspace' } });
	return $c->status(200, $user);
}

=head2 update

Updates user attributes. System admin only.

Response uses the UserDetailed json schema.

=cut

sub update ($c) {
	my $input = $c->validate_input('UpdateUser');
	return if not $input;

	my $user = $c->stash('target_user');
	$c->log->debug('updating user '.$user->email.': '.$c->req->text);
	$user->update($input);

	$user->discard_changes({ prefetch => { user_workspace_roles => 'workspace' } });
	return $c->status(200, $user);
}

=head2 get_me

Just like 'get', only for the logged-in user.
Response uses the UserDetailed json schema.

=cut

sub get_me ($c) {
	my $user = $c->stash('user')
		->discard_changes({ prefetch => { user_workspace_roles => 'workspace' } });
	return $c->status(200, $user);
}

=head2 list

List all users and their workspaces. System admin only.
Response uses the UsersDetailed json schema.

=cut

sub list ($c) {

	my $user_rs = $c->db_user_accounts
		->active
		->prefetch({ user_workspace_roles => 'workspace' });

	return $c->status(200, [ $user_rs->all ]);
}

=head2 create

Creates a user. System admin only.

Optionally takes a query parameter:

* 'send_mail' (defaulting to true), to send an email to the user with the new password

=cut

sub create ($c) {
	my $body =  $c->validate_input('NewUser');
	if (not $body) {
		$c->log->warn('missing body parameters when attempting to create new user');
		return;
	}

	my $name = $body->{name} // $body->{email};
	my $email = $body->{email};

	# this would cause horrible clashes with our /user routes!
	return $c->status(400, { error => 'user name "me" is prohibited', }) if $name eq 'me';

	if (my $user = $c->db_user_accounts->active->lookup_by_id_or_email("email=$email")) {
		return $c->status(409, {
			error => 'duplicate user found',
			user => { map { $_ => $user->$_ } qw(id email name created deactivated) },
		});
	}

	my $password = $body->{password} // $c->random_string;

	my $user = $c->db_user_accounts->create({
		name => $name,
		email => $email,
		password => $password,	# will be hashed in constructor
		is_admin => ($body->{is_admin} ? 1 : 0),
	});
	$c->log->info('created user: ' . $user->name . ', email: ' . $user->email . ', id: ' . $user->id);

	if ($c->req->query_params->param('send_mail') // 1) {
		$c->log->info('sending "welcome new user" mail to user ' . $user->name);
		$c->send_mail(welcome_new_user => {
			(map { $_ => $user->$_ } qw(name email)),
			password => $password,
		});
	}

	return $c->status(201, { map { $_ => $user->$_ } qw(id email name) });
}

=head2 deactivate

Deactivates a user. System admin only.

All workspace permissions are removed and are not recoverable.

=cut

sub deactivate ($c) {
	my $user = $c->stash('target_user');

	if ($user->deactivated) {
		return $c->status(410, {
			error => 'user was already deactivated',
			user => { map { $_ => $user->$_ } qw(id email name created deactivated) },
		});
	}

	my $workspaces = join(', ', map { $_->workspace->name . ' (' . $_->role . ')' }
		$user->related_resultset('user_workspace_roles')->prefetch('workspace')->all);

	$c->log->warn('user ' . $c->stash('user')->name . ' deactivating user ' . $user->name
		. ($workspaces ? ", direct member of workspaces: $workspaces" : ''));
	$user->update({ password => $c->random_string, deactivated => \'NOW()' });

	$user->delete_related('user_workspace_roles');

	if ($c->req->query_params->param('clear_tokens') // 1) {
		$c->log->warn('user ' . $c->stash('user')->name . ' deleting user session tokens for user ' . $user->name);
		$user->delete_related('user_session_tokens');
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
one at http://mozilla.org/MPL/2.0/.

=cut
