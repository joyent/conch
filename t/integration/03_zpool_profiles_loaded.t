use Mojo::Base -strict;
use Test::More;
use Data::UUID;
use IO::All;
use Test::Warnings;
use Test::Conch;

use Data::Printer;

my $uuid = Data::UUID->new;

my $t = Test::Conch->new;

Test::Conch->load_validation_plans(
	[{
		name        => 'Conch v1 Legacy Plan: Server',
		description => 'Test Plan',
		validations => [ { name => 'product_name', version => 1 } ]
	}],
	$t->app->log,
);

$t->schema->storage->dbh_do(sub {
	my ($storage, $dbh, @args) = @_;
	my @test_sql_files =
		qw( 00-hardware.sql 01-hardware-profiles.sql 02-zpool-profiles.sql );
	for my $file ( map { io->file("sql/test/$_") } @test_sql_files ) {
		$dbh->do( $file->all ) or BAIL_OUT("Test SQL load failed");
	}
});


$t->get_ok("/ping")->status_is(200)->json_is( '/status' => 'ok' );
$t->get_ok("/version")->status_is(200);

$t->post_ok(
	"/login" => json => {
		user     => 'conch',
		password => 'conch'
	}
)->status_is(200);
BAIL_OUT("Login failed") if $t->tx->res->code != 200;

isa_ok( $t->tx->res->cookie('conch'), 'Mojo::Cookie::Response' );

$t->get_ok('/workspace')->status_is(200)->json_is( '/0/name', 'GLOBAL' );

my $id = $t->tx->res->json->[0]{id};
BAIL_OUT("No workspace ID") unless $id;

subtest 'Register relay' => sub {
	$t->post_ok(
		'/relay/deadbeef/register',
		json => {
			serial   => 'deadbeef',
			version  => '0.0.1',
			idaddr   => '127.0.0.1',
			ssh_port => '22',
			alias    => 'test relay'
		}
	)->status_is(204);
};

subtest 'Relay List' => sub {
	$t->get_ok('/relay')->status_is(200);
	$t->json_is('/0/id' => 'deadbeef');
};

subtest 'Device Report' => sub {
	my $report =
		io->file('t/integration/resource/passing-device-report.json')->slurp;
	$t->post_ok( '/device/TEST', { 'Content-Type' => 'application/json' }, $report )->status_is(200)
		->json_is( '/status', 'pass' );
};

subtest 'Hardware Product' => sub {

	$t->get_ok("/hardware_product")->status_is(200);
	my @hardware_products = $t->tx->res->json->@*;
	is( scalar @hardware_products, 3 );
	my %hardware_product_hash = map { $_->{name} => $_ } @hardware_products;
	my @hardware_product_names = sort keys %hardware_product_hash;
	is_deeply(
		\@hardware_product_names,
		[
			'2-ssds-1-cpu', '65-ssds-2-cpu',
			'Switch'
		]
	);
	ok(
		defined(
			$hardware_product_hash{'2-ssds-1-cpu'}->{profile}->{zpool}
		),
		'Compute has zpool profile'
	);
	ok(
		defined(
			$hardware_product_hash{'65-ssds-2-cpu'}->{profile}->{zpool}
		),
		'Storage has zpool profile'
	);
	ok( !defined( $hardware_product_hash{'Switch'}->{profile}->{zpool} ),
		'Switch does not have zpool profile' );

	for my $hardware_product (@hardware_products) {
		$t->get_ok( "/hardware_product/" . $hardware_product->{id} )
			->status_is(200)->json_is( '', $hardware_product );
	}
};

done_testing();
