package Conch::DB::ResultSet::Build;
use v5.26;
use warnings;
use parent 'Conch::DB::ResultSet';

use experimental 'signatures';
use Carp ();
use List::Util 'none';

=head1 NAME

Conch::DB::ResultSet::Build

=head1 DESCRIPTION

Interface to queries involving builds.

=head1 METHODS

=head2 user_has_role

Checks that the provided user_id has (at least) the specified role in at least one build in the
resultset.

Returns a boolean.

=cut

sub user_has_role ($self, $user_id, $role) {
    Carp::croak('role must be one of: ro, rw, admin')
        if !$ENV{MOJO_MODE} and none { $role eq $_ } qw(ro rw admin);

    $self
        ->search_related('user_build_roles', { user_id => $user_id })
        ->with_role($role)
        ->exists;
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