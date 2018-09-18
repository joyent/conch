use v5.26;
use warnings;

use Test::More;
use Test::Warnings;
use Test::Conch::Datacenter;

my $t = Test::Conch::Datacenter->new();

$t->get_ok("/ping")->status_is(200)->json_is( '/status' => 'ok' );
$t->get_ok("/version")->status_is(200);


subtest 'device totals' => sub {

    # TODO: DBIx::Class::EasyFixture can make this nicer across lots of tests.

    my $global_ws_id = $t->app->db_workspaces->search({ name => 'GLOBAL' })->get_column('id')->single;
    my $farce = $t->app->db_hardware_products->hri->find({ alias => 'Farce 10' });
    my $test_compute = $t->app->db_hardware_products->hri->find({ alias => 'Test Compute' });

    # find a rack
    my $datacenter_rack = $t->app->db_datacenter_racks->search({}, { rows => 1 })->single;

    # add the rack to the global workspace
    $datacenter_rack->create_related('workspace_datacenter_racks' => { workspace_id => $global_ws_id });

    # create/update some rack layouts
    $datacenter_rack->update_or_create_related('datacenter_rack_layouts', $_) foreach (
        {
            hardware_product_id => $farce->{id},
            rack_unit_start => 1,
        },
        {
            hardware_product_id => $test_compute->{id},
            rack_unit_start => 5,
        },
    );

    # create a few devices and locate them in this rack
    $t->app->db_devices->create($_) foreach (
        {
            id => 'test farce',
            hardware_product_id => $farce->{id},
            state => 'ignore',
            health => 'FAIL',
            device_location => { rack_id => $datacenter_rack->id, rack_unit_start => 1 },
        },
        {
            id => 'test compute',
            hardware_product_id => $test_compute->{id},
            state => 'ignore',
            health => 'PASS',
            device_location => { rack_id => $datacenter_rack->id, rack_unit_start => 5 },
        },
    );

    # doctor the configs so they match the hw products we already have in the test data.
    $t->app->stash('config')->%* = (
        $t->app->stash('config')->%*,
        switch_aliases => [ 'Farce 10' ],
        server_aliases => [],
        storage_aliases => [ 'Test Storage' ],
        compute_aliases => [ 'Test Compute' ],
    );

    $t->get_ok("/workspace/123/device-totals")
        ->status_is(404);

    $t->get_ok("/workspace/$global_ws_id/device-totals")
        ->status_is(200)
        ->json_schema_is('DeviceTotals')
        ->json_is({
            all => [
                { alias => 'Farce 10', count => 1, health => 'FAIL' },
                { alias => 'Test Compute', count => 1, health => 'PASS' }
            ],
            switches => [
                { alias => 'Farce 10', count => 1, health => 'FAIL' },
            ],
            servers => [
                { alias => 'Test Compute', count => 1, health => 'PASS' }
            ],
            storage => [],
            compute => [
                { alias => 'Test Compute', count => 1, health => 'PASS' }
            ],
        });

    $t->get_ok("/workspace/$global_ws_id/device-totals.circ")
        ->status_is(200)
        ->json_schema_is('DeviceTotalsCirconus')
        ->json_is({
            'Farce 10' => {
                health => { PASS => 0, FAIL => 1, UNKNOWN => 0 },
                count => 1,
            },
            'Test Compute' => {
                health => { PASS => 1, FAIL => 0, UNKNOWN => 0 },
                count => 1,
            },
            compute => { count => 1 },
        });
};

done_testing;
# vim: set ts=4 sts=4 sw=4 et :