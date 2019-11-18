package Conch::Route;

use Mojo::Base -strict, -signatures;

use Conch::UUID;
use Conch::Route::Workspace;
use Conch::Route::Device;
use Conch::Route::DeviceReport;
use Conch::Route::Relay;
use Conch::Route::User;
use Conch::Route::HardwareProduct;
use Conch::Route::Validation;
use Conch::Route::Datacenter;
use Conch::Route::HardwareVendor;

=pod

=head1 NAME

Conch::Route

=head1 DESCRIPTION

Set up all the routes for the Conch Mojo application.

=head1 METHODS

=head2 all_routes

Set up the full route structure

=cut

sub all_routes (
    $class,
    $root,  # this is the base routing object
    $app,   # the Conch app
) {

    # provides a route to chain to that first checks the user is a system admin.
    $root->add_shortcut(require_system_admin => sub {
        my ($r, $path) = @_;
        $r->any(sub ($c) {
            return $c->status(401)
                if not $c->stash('user') or not $c->stash('user_id');

            return $c->status(403, { error => 'Must be system admin' })
                if not $c->is_system_admin;

            return 1;
        })->under;
    });

    # allow routes to be specified as, e.g. ->get('/<device_id:uuid>')->to(...)
    $root->add_type(uuid => Conch::UUID::UUID_FORMAT);


    # GET /ping
    $root->get('/ping', sub ($c) { $c->status(200, { status => 'ok' }) });

    # GET /version
    $root->get('/version', sub ($c) {
        $c->res->headers->last_modified(Mojo::Date->new($c->startup_time->epoch));
        $c->status(200, { version => $c->version_tag })
    });

    # POST /login
    $root->post('/login')->to('login#session_login');

    # POST /logout
    $root->post('/logout')->to('login#session_logout');

    # POST /reset_password -> GONE
    $root->post('/reset_password', sub ($c) { $c->status(410) });

    # GET /schema/request/:schema_name
    # GET /schema/response/:schema_name
    $root->get('/schema/:request_or_response/:name',
        [ request_or_response => [qw(request response)] ])->to('schema#get');

    # GET /workspace/:workspace/device-totals
    $root->get('/workspace/:workspace/device-totals')->to('workspace_device#device_totals');

    # all routes after this point require authentication

    my $secured = $root->under('/')->to('login#authenticate');

    $secured->get('/me', sub ($c) { $c->status(204) });
    $secured->post('/refresh_token')->to('login#refresh_token');

    Conch::Route::Workspace->routes($secured->any('/workspace'));
    Conch::Route::Device->routes($secured->any('/device'), $app);
    Conch::Route::DeviceReport->routes($secured->any('/device_report'));
    Conch::Route::Relay->routes($secured->any('/relay'));
    Conch::Route::User->routes($secured->any('/user'));
    Conch::Route::HardwareProduct->routes($secured->any('/hardware_product'));
    Conch::Route::Validation->routes($secured);

    Conch::Route::Datacenter->routes($secured);

    Conch::Route::HardwareVendor->routes($secured->any('/hardware_vendor'));

    $root->any('/*all', sub ($c) {
        $c->log->error('no endpoint found for: '.$c->req->method.' '.$c->req->url->path);
        $c->status(404);
    })->name('catchall');
}

1;
__END__

=pod

Unless otherwise specified all routes require authentication.

=head3 C<GET /ping>

=over 4

=item * Does not require authentication.

=item * Response: response.yaml#/Ping

=back

=head3 C<GET /version>

=over 4

=item * Does not require authentication.

=item * Response: response.yaml#/Version

=back

=head3 C<POST /login>

=over 4

=item * Request: input.yaml#/Login

=item * Response: response.yaml#/Login

=back

=head3 C<POST /logout>

=over 4

=item * Does not require authentication.

=item * Response: C<204 NO CONTENT>

=back

=head3 C<GET /schema/request/:schema_name>

=head3 C<GET /schema/response/:schema_name>

Returns the Request or Response schema specified.

=over 4

=item * Does not require authentication.

=item * Response: JSON-Schema (L<http://json-schema.org/draft-07/schema>)

=back

=head3 C<GET /workspace/:workspace/device-totals>

=head3 C<GET /workspace/:workspace/device-totals.circ>

=over 4

=item * Does not require authentication.

=item * Response: response.yaml#/DeviceTotals

=item * Response (Circonus): response.yaml#/DeviceTotalsCirconus

=back

=head3 C<POST /refresh_token>

=over 4

=item * Request: input.yaml#/Null

=item * Response: response.yaml#/Login

=back


=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<http://mozilla.org/MPL/2.0/>.

=cut
# vim: set ts=4 sts=4 sw=4 et :
