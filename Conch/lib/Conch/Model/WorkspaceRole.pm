=pod

=head1 NAME

Conch::Model::WorkspaceRole

=head1 METHODS

=cut
package Conch::Model::WorkspaceRole;
use Mojo::Base -base, -signatures;

use aliased 'Conch::Class::WorkspaceRole';

has 'pg';

=head2 list

List available workspace roles.

=cut
sub list ( $self ) {
	$self->pg->db->select( 'role', undef )
		->hashes->map( sub { WorkspaceRole->new(shift) } )->to_array;
}

=head2 lookup_by_name

Look up a role by name

=cut
sub lookup_by_name ( $self, $role_name ) {
	my $ret =
		$self->pg->db->select( 'role', undef, { name => $role_name } )->hash;
	return undef unless $ret;
	return WorkspaceRole->new($ret);
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

