=pod

=head1 NAME

Conch::Route

=head1 DESCRIPTION

Set up all the routes for the Conch Mojo app

=head1 METHODS

=cut

package Conch::Route;
use Mojo::Base -strict;

use Conch::Route::Workspace 'workspace_routes';
use Conch::Route::User 'user_routes';
use Conch::Route::Device 'device_routes';
use Conch::Route::Relay 'relay_routes';
use Conch::Route::HardwareProduct 'hardware_product_routes';
use Conch::Route::Validation 'validation_routes';

use Conch::Route::Datacenter;
use Conch::Route::DB::HardwareProduct;
use Conch::Route::HardwareVendor;

use Exporter 'import';
our @EXPORT_OK = qw(
	all_routes
);

=head2 all_routes

Set up the full route structure

=cut

sub all_routes {
	my $root = shift;	# this is the base routing object

	# provides a route to chain to that first checks the user is a system admin.
	$root->add_shortcut(require_system_admin => sub {
		my ($r, $path) = @_;
		$r->any(sub {
			my $c = shift;
			return $c->status(401, { error => 'unauthorized' })
				unless $c->stash('user') and $c->stash('user_id');

			return $c->status(403, { error => 'Must be system admin' })
				unless $c->is_system_admin;

			return 1;
		})->under;
	});

	# CORS preflight check
	$root->options('*', sub{ shift->status(204) });

	$root->get( '/doc',
		sub { shift->reply->static('public/doc/index.html') } );

	$root->get(
		'/version' => sub {
			my $c = shift;
			$c->status( 200, { version => $c->version_tag } );
		}
	);

	$root->post('/login')->to('login#session_login');
	$root->post('/logout')->to('login#session_logout');
	$root->post('/reset_password')->to('login#reset_password');

	# GET /workspace/:workspace/device-totals
	$root->get('/workspace/:workspace/device-totals')->to('workspace_device#device_totals');

	# all routes after this point require authentication

	my $secured = $root->under('/')->to('login#authenticate');

	$secured->get( '/login', sub { shift->status(204) } );
	$secured->get( '/me',    sub { shift->status(204) } );
	$secured->post('/refresh_token')->to('login#refresh_token');

	workspace_routes($secured->any('/workspace'));
	device_routes($secured->any('/device'));
	relay_routes($secured->any('/relay'));
	user_routes($secured->any('/user'));
	hardware_product_routes($secured->any('hardware_product'));
	validation_routes($secured);

	Conch::Route::Datacenter->routes($secured);

	Conch::Route::DB::HardwareProduct->routes($secured->any('/db/hardware_product'));

	Conch::Route::HardwareVendor->routes($secured->any('hardware_vendor'));
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
