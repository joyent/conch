=pod

=head1 NAME

Conch::Controller::WorkspaceProblem

=head1 METHODS

=cut

package Conch::Controller::WorkspaceProblem;

use Mojo::Base 'Mojolicious::Controller', -signatures;

use Conch::Legacy::Schema;
use Conch::Legacy::Control::Problem 'get_problems';



=head2 list

Get a list of problems for a workspace, using the Legacy code base

=cut

# get_problems needs to be heavily re-worked. For now, use the legacy code using DBIC
sub list ($c) {
	my $schema = Conch::Legacy::Schema->connect( $c->pg->dsn, $c->pg->username,
		$c->pg->password );

	my $problems = get_problems(
		$schema,
		$c->stash('user_id'),
		$c->stash('current_workspace')->id
	);
	$c->status( 200, $problems );
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

