package Conch::Route::Build;

use Mojo::Base -strict, -signatures;

=pod

=head1 NAME

Conch::Route::Build

=head1 METHODS

=head2 routes

Sets up the routes for /build.

=cut

sub routes {
    my $class = shift;
    my $build = shift; # secured, under /build

    $build->to({ controller => 'build' });

    # GET /build
    $build->get('/')->to('#list');

    # POST /build
    $build->require_system_admin->post('/')->to('#create');

    {
        # chainable actions that extract and looks up build_id from the path
        # and performs basic role checking for the build
        my $with_build_ro = $build->under('/:build_id_or_name')
            ->to('#find_build', require_role => 'ro');

        my $with_build_admin = $build->under('/:build_id_or_name')
            ->to('#find_build', require_role => 'admin');

        # GET /build/:build_id_or_name
        $with_build_ro->get('/')->to('#get');

        # POST /build/:build_id_or_name
        $with_build_admin->post('/')->to('#update');
    }
}

1;
__END__

=pod

Unless otherwise noted, all routes require authentication.

=head3 C<GET /build>

=over 4

=item * Response: response.yaml#/Builds

=back

=head3 C<POST /build>

=over 4

=item * Requires system admin authorization

=item * Request: request.yaml#/BuildCreate

=item * Response: Redirect to the build

=back

=head3 C<GET /build/:build_id_or_name>

=over 4

=item * Requires system admin authorization or the read-only role on the build

=item * Response: response.yaml#/Build

=back

=head3 C<POST /build/:build_id_or_name>

=over 4

=item * Requires system admin authorization or the admin role on the build

=item * Request: request.yaml#/BuildUpdate

=item * Response: Redirect to the build

=back

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<http://mozilla.org/MPL/2.0/>.

=cut
# vim: set ts=4 sts=4 sw=4 et :
