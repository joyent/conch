use v5.26;
use Mojo::Base -strict, -signatures;

use Test::More;
use Test::Warnings;
use Path::Tiny;
use Test::Deep;
use Test::Conch;
use Mojo::JSON 'from_json';

my $t = Test::Conch->new;
$t->load_fixture_set('workspace_room_rack_layout', 0);

my $rack = $t->load_fixture('rack_0a');
my $rack_id = $rack->id;
my $hardware_product = $t->load_fixture('hardware_product_compute');
my $hardware_product2 = $t->load_fixture('hardware_product_storage');
my $global_ws = $t->load_fixture('global_workspace');

$t->load_validation_plans([{
    id          => $hardware_product->validation_plan_id,
    name        => 'our plan',
    description => 'Test Plan',
    validations => [ 'Conch::Validation::DeviceProductName' ],
}]);

# perform most tests as a user with read only access to the GLOBAL workspace
my $null_user = $t->generate_fixtures('user_account');
my $ro_user = $t->load_fixture('ro_user_global_workspace')->user_account;
my $rw_user = $t->load_fixture('rw_user_global_workspace')->user_account;
my $admin_user = $t->load_fixture('admin_user_global_workspace')->user_account;
my $super_user = $t->load_fixture('super_user');
my $build_user = $t->generate_fixtures('user_account', { name => 'build_user' });

my $build = $t->generate_fixtures('build');
$build->create_related('user_build_roles', { user_id => $build_user->id, role => 'admin' });
$t->authenticate(email => $build_user->email)
    ->post_ok('/build/'.$build->id.'/device', json => [ { serial_number => 'TEST', sku => $hardware_product->sku } ])
    ->status_is(204);

my $build2 = $t->generate_fixtures('build');
$build2->create_related('user_build_roles', { user_id => $build_user->id, role => 'admin' });

$t->authenticate(email => $ro_user->email);

$t->get_ok('/device/nonexistent')
    ->status_is(404)
    ->log_debug_is('Could not find device nonexistent');

my $test_device_id;

subtest 'unlocated device, no registered relay' => sub {
    my $report_data = from_json(path('t/integration/resource/passing-device-report.json')->slurp_utf8);
    $t->post_ok('/device_report', json => $report_data)
        ->status_is(409)
        ->json_schema_is('Error')
        ->json_is({ error => 'relay serial deadbeef is not registered' });

    delete $report_data->{relay};

    $t->post_ok('/device_report', json => $report_data)
        ->status_is(200)
        ->json_schema_is('ValidationStateWithResults');

    $test_device_id = $t->tx->res->json->{device_id};
    my $device_report_id = $t->tx->res->json->{device_report_id};

    $t->get_ok('/device/TEST')
        ->status_is(403)
        ->log_debug_is('User lacks the required role (ro) for device '.$test_device_id);

    $t->get_ok('/device_report/'.$device_report_id)
        ->status_is(403)
        ->log_debug_is('User lacks the required role (ro) for device '.$test_device_id);

    {
        my $t = Test::Conch->new(pg => $t->pg);
        $t->authenticate(email => $super_user->email);

        $t->get_ok('/device/TEST')
            ->status_is(200)
            ->json_schema_is('DetailedDevice')
            ->json_is('/id', $test_device_id)
            ->json_is('/serial_number', 'TEST')
            ->log_debug_is('User has system admin privileges for device '.$test_device_id);

        $t->get_ok('/device/'.$test_device_id)
            ->status_is(200)
            ->json_schema_is('DetailedDevice')
            ->json_is('/id', $test_device_id)
            ->json_is('/serial_number', 'TEST')
            ->log_debug_is('User has system admin privileges for device '.$test_device_id);

        $t->get_ok('/device_report/'.$device_report_id)
            ->status_is(200)
            ->json_schema_is('DeviceReportRow')
            ->log_debug_is('User has system admin privileges for device '.$test_device_id);
    }

    {
        my $t_build = Test::Conch->new(pg => $t->pg);
        $t_build->authenticate(email => $build_user->email);

        $t_build->get_ok('/device/TEST')
            ->status_is(200)
            ->json_schema_is('DetailedDevice')
            ->json_is('/id', $test_device_id)
            ->json_is('/serial_number', 'TEST')
            ->log_debug_is('User has ro access to device '.$test_device_id.' via role entry');

        $t_build->get_ok('/device/'.$test_device_id)
            ->status_is(200)
            ->json_schema_is('DetailedDevice')
            ->json_is('/id', $test_device_id)
            ->json_is('/serial_number', 'TEST')
            ->log_debug_is('User has ro access to device '.$test_device_id.' via role entry');

        $t_build->get_ok('/device_report/'.$device_report_id)
            ->status_is(200)
            ->json_schema_is('DeviceReportRow')
            ->log_debug_is('User has ro access to device '.$test_device_id.' via role entry');
    }

    $t->authenticate(email => $ro_user->email);
};

subtest 'unlocated device with a registered relay' => sub {
    $t->post_ok('/relay/deadbeef/register', json => { serial => 'deadbeef' })
        ->status_is(201);

    my $report = path('t/integration/resource/passing-device-report.json')->slurp_utf8;
    $t->post_ok('/device_report', { 'Content-Type' => 'application/json' }, $report)
        ->status_is(200)
        ->json_schema_is('ValidationStateWithResults');

    my $validation_state = $t->tx->res->json;

    $t->get_ok('/device_report/'.$validation_state->{device_report_id})
        ->status_is(200)
        ->json_schema_is('DeviceReportRow')
        ->json_cmp_deeply({
            id => $validation_state->{device_report_id},
            device_id => $test_device_id,
            report => from_json($report),
            created => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/),
        });

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            id => $test_device_id,
            serial_number => 'TEST',
            health => 'pass',
            hostname => 'elfo',
            system_uuid => ignore,
            phase => 'integration',
            links => [],
            (map +('build_'.$_ => $build->$_), qw(id name)),
            (map +($_ => undef), qw(asset_tag uptime_since validated)),
            (map +($_ => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/)), qw(created updated last_seen)),
            hardware_product_id => $hardware_product->id,
            sku => $hardware_product->sku,
            location => undef,
            latest_report => from_json($report),
            nics => supersetof(),
            disks => supersetof(superhashof({ serial_number => 'BTHC640405WM1P6PGN' })),
        });
    my $test_device_data = $t->tx->res->json;

    $t->app->db_device_disks->deactivate;
    $test_device_data->{disks} = [];

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply($test_device_data)
        ->log_debug_is('User has de facto ro access to device '.$test_device_id.' via relay connection');

    $t->get_ok('/validation_state/'.$validation_state->{id})
        ->status_is(200)
        ->json_schema_is('ValidationStateWithResults')
        ->json_is($validation_state);

    cmp_deeply(
        [ $t->validator->validate(
            {
                do { my %_data = $test_device_data->%*; delete $_data{location}; %_data },
                phase => 'integration',
            },
            $t->validator->get('/definitions/DetailedDevice')) ],
        [
            methods(
                path => '/location',
                message => re(qr/missing property/i),
            ),
        ],
        'lack of location data is rejected by the response schema when phase=integration',
    );

    cmp_deeply(
        [ $t->validator->validate(
            { $test_device_data->%*, phase => 'production' },
            $t->validator->get('/definitions/DetailedDevice')) ],
        [
            methods(
                path => '/',
                message => re(qr/should not match/i),
            ),
        ],
        'location data is rejected by the response schema when phase=production',
    );

    $t->app->db_devices->search({ id => $test_device_id })->update({ phase => 'production' });

    $test_device_data->{phase} = 'production';
    delete $test_device_data->@{qw(location nics disks)};
    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply($test_device_data);

    my @post_queries = (
        [ '/device/TEST/validated' ],
        [ '/device/TEST/phase', json => { phase => 'installation' } ],
        [ '/device/TEST/links', json => { links => [ 'https://foo.com/1' ] } ],
        [ '/device/TEST/settings/hello', json => { hello => 'world' } ],
        [ '/device/TEST/settings/tag.hello', json => { 'tag.hello' => 'hi' } ],
    );

    foreach my $query (@post_queries) {
        $t->post_ok($query->@*);
        if ($query->[0] =~ /settings/) {
            $t->status_is(204);
        } else {
            $t->status_is(303)
            ->location_is('/device/'.$test_device_id);
        }
    }

    $t->app->db_device_nics->create({
        device_id => $test_device_id,
        iface_name => 'home',
        iface_type => 'me',
        iface_vendor => 'me',
        mac => '00:00:00:00:00:00',
        ipaddr => '127.0.0.1',
    });

    my @get_queries = (
        '/device/TEST',
        '/device/TEST/settings',
        '/device/TEST/settings/hello',
        '/device/TEST/settings/tag.hello',
        '/device/TEST/validation_state',
        '/device/TEST/interface',
        '/device/TEST/phase',
        '/device?hostname=elfo',
        '/device?mac=00:00:00:00:00:00',
        '/device?ipaddr=127.0.0.1',
        '/device?link=https://foo.com/1',
    );

    foreach my $query (@get_queries) {
        $t->get_ok($query)
            ->status_is(200);
    }

    my $t2 = Test::Conch->new(pg => $t->pg);
    $t2->authenticate(email => $null_user->email);

    $t2->get_ok('/device/TEST')
        ->status_is(403)
        ->log_debug_is('User lacks the required role (ro) for device '.$test_device_id);

    $t2->get_ok('/device_report/'.$validation_state->{device_report_id})
        ->status_is(403)
        ->log_debug_is('User lacks the required role (ro) for device '.$test_device_id);

    foreach my $query (@post_queries) {
        $t2->post_ok($query->@*)
            ->status_is(403)
            ->log_debug_is('User lacks the required role (rw) for device '.$test_device_id);
    }

    foreach my $query (@get_queries) {
        $t2->get_ok($query)
            ->status_is(403)
            ->log_debug_is(
                $query =~ /TEST/ ? 'User lacks the required role (ro) for device '.$test_device_id
                : 'User cannot access requested device(s)');
    }

    my @delete_queries = (
        '/device/TEST/settings/hello',
        '/device/TEST/settings/tag.hello',
        '/device/TEST/links',
    );

    foreach my $query (@delete_queries) {
        $t2->delete_ok($query)
            ->status_is(403)
            ->log_debug_is('User lacks the required role (rw) for device '.$test_device_id);
    }

    foreach my $query (@delete_queries) {
        $t->delete_ok($query)
            ->status_is(204);
    }

    $null_user->update({ is_admin => 1 });

    $t2->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice');

    foreach my $query (@post_queries) {
        $t2->post_ok($query->@*)
            ->location_is('/device/'.$test_device_id);
        if ($query->[0] =~ /settings|validated|phase/) {
            $t2->status_is(204);
        } else {
            $t2->status_is(303);
        }
    }

    foreach my $query (@get_queries) {
        $t2->get_ok($query)
            ->status_is(200);
    }

    foreach my $query (@delete_queries) {
        $t2->delete_ok($query)
            ->status_is(204);
    }

    $t->get_ok('/device_report/'.$validation_state->{device_report_id})
        ->status_is(200)
        ->json_schema_is('DeviceReportRow');

    $null_user->update({ is_admin => 0 });
    #$t->app->db_device_nics->search({ device_id => $test_device_id })->delete;
};

my $located_device_id;

subtest 'located device' => sub {
    # create the device in the requested rack location
    my $located_device = $t->app->db_devices->create({
        serial_number => 'LOCATED_DEVICE',
        hardware_product_id => $t->app->db_rack_layouts->search({ rack_id => $rack_id, rack_unit_start => 1 })->get_column('hardware_product_id')->as_query,
        health => 'unknown',
        device_location => { rack_id => $rack_id, rack_unit_start => 1 },
    });

    $located_device_id = $located_device->id;

    $t->get_ok('/device/'.$located_device_id)
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            id => $located_device_id,
            serial_number => 'LOCATED_DEVICE',
            health => 'unknown',
            phase => 'integration',
            links => [],
            (map +('build_'.$_ => undef), qw(id name)),
            (map +($_ => undef), qw(asset_tag hostname last_seen system_uuid uptime_since validated)),
            (map +($_ => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/)), qw(created updated)),
            hardware_product_id => $hardware_product->id,
            sku => $hardware_product->sku,
            location => {
                az => 'room-0a',
                datacenter_room => 'room 0a',
                rack => 'ROOM:0.A:rack.0a',
                rack_unit_start => 1,
                target_hardware_product => superhashof({ alias => 'Test Compute' }),
            },
            latest_report => undef,
            nics => [],
            disks => [],
        });
    my $device_data = $t->tx->res->json;

    $located_device->update({ hostname => 'located_host' });
    $device_data->{hostname} = 'located_host';

    {
        my $t = Test::Conch->new(pg => $t->pg);
        my $null_user = $t->generate_fixtures('user_account');
        $t->authenticate(email => $null_user->email);
        $t->get_ok('/device/'.$located_device_id)
            ->status_is(403)
            ->log_debug_is('User lacks the required role (ro) for device '.$located_device_id);

        $t->get_ok('/device?hostname=located_host')
            ->status_is(403)
            ->log_debug_is('User cannot access requested device(s)');

        $global_ws->create_related('user_workspace_roles', { user_id => $null_user->id, role => 'ro' });

        $t->get_ok('/device/'.$located_device_id)
            ->status_is(200)
            ->json_schema_is('DetailedDevice')
            ->json_cmp_deeply($device_data);

        $t->get_ok('/device?hostname=located_host')
            ->status_is(200)
            ->json_schema_is('Devices')
            ->json_cmp_deeply([ superhashof({ id => $located_device_id }) ]);
    }

    $t->txn_local('remove device from its workspace', sub ($t) {
        $t->app->db_workspace_racks->delete;
        $t->get_ok('/device/LOCATED_DEVICE')
            ->status_is(403)
            ->log_debug_is('User lacks the required role (ro) for device '.$located_device_id);
    });

    subtest 'required role for POST queries' => sub {
        my @post_queries = (
            [ '/device/LOCATED_DEVICE/validated' ],
            [ '/device/LOCATED_DEVICE/settings/hello', json => { hello => 'world' } ],
            [ '/device/LOCATED_DEVICE/settings/tag.hello', json => { 'tag.hello' => 'hi' } ],
            [ '/device/LOCATED_DEVICE/settings/tag.hello', json => { 'tag.hello' => 'bye' } ], # not a typo!
            [ '/device/LOCATED_DEVICE/phase', json => { phase => 'installation' } ],
            [ '/device/LOCATED_DEVICE/links', json => { links => [ 'https://foo.com/1' ] } ],
        );

        $t->authenticate(email => $rw_user->email);
        foreach my $query (@post_queries) {
            $t->post_ok($query->@*);
            if ($query->[0] =~ /settings/) {
                $t->status_is(204);
            } else {
                $t->status_is(303)
                    ->location_is('/device/'.$located_device_id);
            }
        }
        $t->post_ok('/device/LOCATED_DEVICE/settings/hello', json => { 'hello' => 'bye' })
            ->status_is(403)
            ->log_debug_is('User lacks the required role (admin) for device '.$located_device_id);

        $t->post_ok('/device/LOCATED_DEVICE/'.$_, json => { sku => $hardware_product2->sku })
            ->status_is(403)
            ->log_debug_is('User lacks the required role (admin) for device '.$located_device_id)
                foreach qw(hardware_product sku);

        $t->authenticate(email => $admin_user->email);
        $t->post_ok('/device/LOCATED_DEVICE/settings/hello', json => { 'hello' => 'bye' })
            ->status_is(204);

        $t->post_ok('/device/LOCATED_DEVICE/sku', json => { sku => $hardware_product2->sku })
            ->status_is(303)
            ->location_is('/device/'.$located_device_id);

        $t->authenticate(email => $ro_user->email);
        foreach my $query (@post_queries) {
            $t->post_ok($query->@*)
                ->status_is(403)
                ->log_debug_is('User lacks the required role (rw) for device '.$located_device_id);
        }
    };

    subtest 'required role for GET queries' => sub {
        $located_device->update({ hostname => 'Luci' });
        $t->app->db_device_nics->update_or_create({
            device_id => $located_device_id,
            iface_name => 'home',
            iface_type => 'me',
            iface_vendor => 'me',
            mac => '00:00:00:00:00:00',
            ipaddr => '127.0.0.1',
        });

        $t->get_ok('/device/LOCATED_DEVICE')
            ->status_is(200)
            ->json_schema_is('DetailedDevice');
        $device_data = $t->tx->res->json;

        my @get_queries = (
            '/device/LOCATED_DEVICE',
            '/device/LOCATED_DEVICE/location',
            '/device/LOCATED_DEVICE/settings',
            '/device/LOCATED_DEVICE/settings/hello',
            '/device/LOCATED_DEVICE/settings/tag.hello',
            '/device/LOCATED_DEVICE/validation_state',
            '/device/LOCATED_DEVICE/interface',
            '/device/LOCATED_DEVICE/phase',
            '/device?hostname=Luci',
            '/device?mac=00:00:00:00:00:00',
            '/device?ipaddr=127.0.0.1',
            '/device?link=https://foo.com/1',
        );

        foreach my $query (@get_queries) {
            $t->get_ok($query)
                ->status_is(200);
        }

        $t->txn_local('remove all workspace roles', sub ($t) {
            $t->app->db_user_workspace_roles->delete;

            foreach my $query (@get_queries) {
                $t->get_ok($query)
                    ->status_is(403)
                    ->log_debug_is(
                        $query =~ /LOCATED_DEVICE/ ? 'User lacks the required role (ro) for device '.$located_device_id
                        : 'User cannot access requested device(s)');
            }

            $ro_user->update({ is_admin => 1 });
            foreach my $query (@get_queries) {
                $t->get_ok($query)
                    ->status_is(200);
            }
            $ro_user->update({ is_admin => 0 });
        });
    };


    subtest 'required role for DELETE queries' => sub {
        $t->authenticate(email => $ro_user->email);

        foreach my $query (qw(
            /device/LOCATED_DEVICE/settings/hello
            /device/LOCATED_DEVICE/settings/tag.hello
            /device/LOCATED_DEVICE/links
        )) {
            $t->delete_ok($query)
                ->status_is(403)
                ->log_debug_is('User lacks the required role (rw) for device '.$located_device_id);
        }

        $t->authenticate(email => $rw_user->email);
        $t->delete_ok('/device/LOCATED_DEVICE/settings/hello')
            ->status_is(403)
            ->log_debug_is('User lacks the required role (admin) for device '.$located_device_id);
        $t->delete_ok('/device/LOCATED_DEVICE/settings/tag.hello')
            ->status_is(204);
        $t->delete_ok('/device/LOCATED_DEVICE/links')
            ->status_is(204);
        $device_data->{links} = [];

        $t->authenticate(email => $admin_user->email);
        $t->delete_ok('/device/LOCATED_DEVICE/settings/hello')
            ->status_is(204);

        $t->authenticate(email => $ro_user->email);
    };

    # give build user rw access to the device through device->device_location->rack->workspace
    $global_ws->create_related('user_workspace_roles', { user_id => $build_user->id, role => 'rw' });
    $t->authenticate(email => $build_user->email);
    $t->post_ok('/build/'.$build->id.'/device/'.$located_device_id)
        ->status_is(204)
        ->log_debug_is('User has rw access to build '.$build->id.' via role entry')
        ->log_debug_is('User has rw access to device '.$located_device_id.' via role entry');

    $located_device->update({ phase => 'production' });
    $device_data->@{qw(build_id build_name)} = map $build->$_, qw(id name);
    $device_data->{phase} = 'production';
    delete $device_data->@{qw(location nics disks)};

    # build user still has access through the build
    $t->get_ok('/device/'.$located_device_id)
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            $device_data->%*,
            updated => re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/),
        })
        ->log_debug_is('User has ro access to device '.$located_device_id.' via role entry');

    # ro user only had access through device->device_location->rack->workspace
    $t->authenticate(email => $ro_user->email);
    $t->get_ok('/device/'.$located_device_id)
        ->status_is(403)
        ->log_debug_is('User lacks the required role (ro) for device '.$located_device_id);

    $located_device->update({ phase => 'installation' });
};

subtest 'device network interfaces' => sub {
    $t->get_ok('/device/TEST/interface')
        ->status_is(200)
        ->json_schema_is('DeviceNics');

    $t->get_ok('/device/TEST/interface/ipmi1')
        ->status_is(200)
        ->json_schema_is('DeviceNic');

    $t->get_ok('/device/TEST/interface/ipmi1/'.$_)
        ->status_is(404)
        ->log_warn_is('no endpoint found for: GET /device/TEST/interface/ipmi1/'.$_)
            foreach qw(device_id created);

    $t->get_ok('/device/TEST/interface/ipmi1/mac')
        ->status_is(200)
        ->json_schema_is('DeviceNicField')
        ->json_is({ mac => '18:66:da:78:d9:b3' });

    $t->get_ok('/device/TEST/interface/ipmi1/ipaddr')
        ->status_is(200)
        ->json_schema_is('DeviceNicField')
        ->json_is({ ipaddr => '10.72.160.146' });

    $t->post_ok('/device/TEST/phase', json => { phase => 'production' })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);

    foreach my $query (
        '/device/TEST/interface',
        '/device/TEST/interface/ipmi1',
        map '/device/TEST/interface/ipmi1/'.$_,
            (qw(mac iface_name iface_type iface_vendor state ipaddr mtu)),
    ) {
        $t->get_ok($query)
            ->status_is(409)
            ->location_is('/device/'.$test_device_id.'/links')
            ->json_is({ error => 'device is in the production phase' });
    }

    $t->get_ok('/device/TEST/interface?phase_earlier_than=decommissioned')
        ->status_is(200)
        ->json_schema_is('DeviceNics');

    $t->get_ok('/device/TEST/interface?phase_earlier_than=')
        ->status_is(200)
        ->json_schema_is('DeviceNics');

    $t->post_ok('/device/TEST/phase', json => { phase => 'installation' })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);
};

$t->get_ok('/device/TEST')
    ->status_is(200)
    ->json_schema_is('DetailedDevice');

my $detailed_device = $t->tx->res->json;

subtest 'caching' => sub {
    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->header_is('Cache-Control', 'no-cache')
        ->header_like('ETag', qr{^W/"[^"]+"$})
        ->json_schema_is('DetailedDevice')
        ->json_is($detailed_device);

    my $etag = $t->tx->res->headers->etag;

    $t->get_ok('/device/TEST' => { 'If-None-Match'=> $etag })
        ->status_is(304)
        ->header_is('Cache-Control', 'no-cache');

    $t->get_ok('/device/TEST' => { 'If-None-Match'=> 'whargarbl' })
        ->status_is(200)
        ->header_is('Cache-Control', 'no-cache')
        ->header_is('ETag', $etag)
        ->json_schema_is('DetailedDevice')
        ->json_is($detailed_device);
};

$t->app->db_device_nics->create({
    mac => '00:00:00:00:00:0'.$_,
    device_id => $test_device_id,
    iface_name => $_,
    iface_type => 'foo',
    iface_vendor => 'bar',
    deactivated => \'now()',
}) foreach (7..9);

my @macs = map $_->{mac}, $detailed_device->{nics}->@*;

my $undetailed_device = {
    $detailed_device->%*,
    ($t->app->db_devices->search({ 'device.id' => $test_device_id })->columns([])->with_device_location->hri->single // {})->%{qw(rack_id rack_unit_start rack_name)},
};
delete $undetailed_device->@{qw(latest_report location nics disks)};

subtest 'get by device attributes' => sub {
    $t->get_ok('/device?hostname=elfo')
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is('', [ $undetailed_device ], 'got device by hostname');

    $t->get_ok("/device?mac=$macs[0]")
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is('', [ $undetailed_device ], 'got device by mac');

    # device_nics->[2] has ipaddr' => '172.17.0.173'.
    $t->get_ok('/device?ipaddr=172.17.0.173')
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is('', [ $undetailed_device ], 'got device by ipaddr');

    my $test_device = $t->app->db_devices->search({ id => $test_device_id })->single;
    $test_device->update({ links => ['http://foo.com'] });
    $undetailed_device->{links} = ['http://foo.com'];

    $t->get_ok('/device?link=http://foo.com')
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is('', [ $undetailed_device ], 'got device by link');

    $t->get_ok('/device?key=value')
        ->status_is(404)
        ->log_debug_is('Could not find devices matching key=value');

    $test_device->create_related('device_settings', { name => 'key', value => 'value' });

    $t->get_ok('/device?key=ugh')
        ->status_is(404)
        ->log_debug_is('Could not find devices matching key=ugh');

    $t->get_ok('/device?key=value')
        ->status_is(200)
        ->json_schema_is('Devices')
        ->json_is([ $undetailed_device ]);

    $test_device->update({ phase => 'production' });

    $undetailed_device->{phase} = 'production';
    delete $undetailed_device->@{qw(rack_id rack_unit_start rack_name)};

    foreach my $query (qw(
        /device?hostname=elfo
        /device?link=http://foo.com
        /device?key=value
    )) {
        $t->get_ok($query)
            ->status_is(200)
            ->json_schema_is('Devices')
            ->json_is([ $undetailed_device ]);
    }

    foreach my $query ('/device?ipaddr=172.17.0.173', "/device?mac=$macs[0]") {
        $t->get_ok($query)->status_is(404);
    }

    $test_device->update({ links => '{}', phase => 'installation' });
};

subtest 'mutate device attributes' => sub {
    $t->post_ok('/device/nonexistent/validated')
        ->status_is(404)
        ->log_debug_is('Could not find device nonexistent');

    $t->post_ok('/device/TEST/asset_tag')
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/', message => re(qr/expected object/i) } ]);

    $t->post_ok('/device/TEST/asset_tag', json => { asset_tag => 'asset tag' })
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [
            { path => '/asset_tag', message => re(qr/String does not match/) },
            { path => '/asset_tag', message => re(qr/Not null/) },
        ]);

    $t->post_ok('/device/TEST/asset_tag', json => { asset_tag => 'asset_tag' })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);

    $t->post_ok('/device/TEST/asset_tag', json => { asset_tag => undef })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);

    $t->app->db_devices->search({ serial_number => 'TEST' })->update({ validated => undef });
    $t->post_ok('/device/TEST/validated')
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);
    $detailed_device->{validated} = re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/);

    $t->post_ok('/device/TEST/validated')
        ->status_is(204);

    $t->post_ok('/device/TEST/phase', json => { phase => 'decommissioned' })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);

    local $detailed_device->{phase} = 'decommissioned';
    delete local $detailed_device->@{qw(location nics disks)};

    my $test_device = $t->app->db_devices->find({ serial_number => 'TEST' }, { prefetch => 'hardware_product' });

    $t->get_ok('/device/TEST/phase')
        ->status_is(200)
        ->json_schema_is('DevicePhase')
        ->json_is({ id => $test_device_id, phase => 'decommissioned' });

    $t->get_ok('/device/TEST/sku')
        ->status_is(200)
        ->json_schema_is('DeviceSku')
        ->json_is({
            id => $test_device_id,
            hardware_product_id => $hardware_product->id,
            sku => $hardware_product->sku,
        });

    $t->delete_ok('/device/TEST/links')
        ->status_is(204);

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            $detailed_device->%*,
            updated => str($test_device->updated),    # needless update is not performed
        });

    $t->post_ok('/device/TEST/hardware_product', json => { sku => $hardware_product2->sku })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);
    $detailed_device->@{qw(hardware_product_id sku)} = map $hardware_product2->$_, qw(id sku);

    $t->get_ok('/device/TEST/sku')
        ->status_is(200)
        ->json_schema_is('DeviceSku')
        ->json_is({
            id => $test_device_id,
            hardware_product_id => $hardware_product2->id,
            sku => $hardware_product2->sku,
        });

    $t->post_ok('/device/TEST/links', json => { links => [ 'https://foo.com/1' ] })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);
    $detailed_device->{links} = [ 'https://foo.com/1' ];
    $detailed_device->{updated} = re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/);

    $t->post_ok('/device/TEST/build', json => { build_id => $build2->id })
        ->status_is(403)
        ->log_debug_is('User lacks the required role (rw) for existing build '.$build->id);
    my $ubr = $build->create_related('user_build_roles', { user_id => $ro_user->id, role => 'rw' });

    $t->post_ok('/device/TEST/build', json => { build_id => $build2->id })
        ->status_is(403)
        ->log_debug_is('User lacks the required role (rw) for new build '.$build2->id);

    $build2->create_related('user_build_roles', { user_id => $ro_user->id, role => 'rw' });

    $t->post_ok('/device/TEST/build', json => { build_id => $build2->id })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);
    $detailed_device->@{qw(build_id build_name)} = map $build2->$_, qw(id name);

    $ubr->delete;

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply($detailed_device);
    $detailed_device->{updated} = $t->tx->res->json->{updated};

    $t->post_ok('/device/TEST/links', json => { links => [ 'https://foo.com/1' ] })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply($detailed_device);

    $t->post_ok('/device/TEST/links', json => { links => [ 'https://foo.com/1', 'https://foo.com/0' ] })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id);
    $detailed_device->{links} = [ 'https://foo.com/0', 'https://foo.com/1' ];
    $detailed_device->{updated} = re(qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,9}Z$/);

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply($detailed_device);

    $t->delete_ok('/device/TEST/links', json => { links => [ 'https://does-not-exist.com' ] })
        ->status_is(204);

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply($detailed_device);

    $t->delete_ok('/device/TEST/links', json => { links => [ 'https://foo.com/1' ] })
        ->status_is(204);
    $detailed_device->{links} = [ 'https://foo.com/0' ];

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply($detailed_device);

    $t->delete_ok('/device/TEST/links')
        ->status_is(204);
    $detailed_device->{links} = [];

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply($detailed_device);

    $test_device->update({ phase => 'installation' });
};

subtest 'Device settings' => sub {
    # device settings that check for the 'admin' role need the device to have a location
    $t->authenticate(email => $admin_user->email);

    $t->app->db_device_settings->search({ device_id => $located_device_id })->delete;

    $t->get_ok('/device/LOCATED_DEVICE/settings')
        ->status_is(200)
        ->json_schema_is('DeviceSettings')
        ->json_is({});

    $t->get_ok('/device/LOCATED_DEVICE/settings/foo')
        ->status_is(404)
        ->log_debug_is('Could not find device setting foo for device '.$located_device_id);

    $t->post_ok('/device/LOCATED_DEVICE/settings')
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/', message => re(qr/expected object/i) } ]);

    $t->post_ok('/device/LOCATED_DEVICE/settings/foo', json => { foo => 'bar', baz => 'quux' })
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/', message => re(qr/too many properties/i) } ]);

    $t->post_ok('/device/LOCATED_DEVICE/settings/FOO/BAR', json => { 'FOO/BAR' => 'foo' })
        ->status_is(404)
        ->log_warn_is('no endpoint found for: POST /device/LOCATED_DEVICE/settings/FOO/BAR');

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { foo => 'baz' })
        ->status_is(204);

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { foo => 2 })
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings')
        ->status_is(200)
        ->json_schema_is('DeviceSettings')
        ->json_is({ foo => 2 });

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { foo => JSON::PP::true })
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings')
        ->status_is(200)
        ->json_schema_is('DeviceSettings')
        ->json_is({ foo => 1 });

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { foo => 'bar' })
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings')
        ->status_is(200)
        ->json_schema_is('DeviceSettings')
        ->json_is({ foo => 'bar' });

    $t->get_ok('/device/LOCATED_DEVICE/settings/foo')
        ->status_is(200)
        ->json_schema_is('DeviceSetting')
        ->json_is({ foo => 'bar' });

    $t->post_ok('/device/LOCATED_DEVICE/settings/foo', json => { bar => 'baz' })
        ->status_is(400)
        ->json_is({ error => "Setting key in request payload must match name in the URL ('foo')" });

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { foo => undef })
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/foo', message => re(qr/expected string.*got null/i) } ]);

    $t->post_ok('/device/LOCATED_DEVICE/settings/foo', json => { foo => undef })
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/foo', message => re(qr/expected string.*got null/i) } ]);

    $t->post_ok('/device/LOCATED_DEVICE/settings/foo', json => { foo => { bar => 'baz' } })
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/foo', message => re(qr/expected string.*got object/i) } ]);

    $t->post_ok('/device/LOCATED_DEVICE/settings/fizzle', json => { no_match => 'gibbet' })
        ->status_is(400);

    $t->post_ok('/device/LOCATED_DEVICE/settings/fizzle', json => { fizzle => 'gibbet' })
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings/fizzle')
        ->status_is(200)
        ->json_schema_is('DeviceSetting')
        ->json_is('/fizzle', 'gibbet');

    $t->delete_ok('/device/LOCATED_DEVICE/settings/fizzle')
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings/fizzle')
        ->status_is(404)
        ->log_debug_is('Could not find device setting fizzle for device '.$located_device_id);

    $t->delete_ok('/device/LOCATED_DEVICE/settings/fizzle')
        ->status_is(404)
        ->log_debug_is('Could not find device setting fizzle for device '.$located_device_id);

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { 'tag.foo' => 'foo', 'tag.bar' => 'bar' })
        ->status_is(204);

    $t->post_ok('/device/LOCATED_DEVICE/settings/tag.bar', json => { 'tag.bar' => 'newbar' })
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(200)
        ->json_schema_is('DeviceSetting')
        ->json_is('/tag.bar', 'newbar', 'Setting was updated');

    $t->delete_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(204);

    $t->get_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(404)
        ->log_debug_is('Could not find device setting tag.bar for device '.$located_device_id);

    $t->get_ok('/device/LOCATED_DEVICE')
        ->status_is(200)
        ->json_schema_is('DetailedDevice');

    $t->authenticate(email => $ro_user->email);

    $t->post_ok('/device/LOCATED_DEVICE/settings/foo', json => { foo => 'new_value' })
        ->status_is(403)
        ->log_debug_is('User lacks the required role (rw) for device '.$located_device_id);
    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { name => 'new value' })
        ->status_is(403)
        ->log_debug_is('User lacks the required role (rw) for device '.$located_device_id);
    $t->delete_ok('/device/LOCATED_DEVICE/settings/foo')
        ->status_is(403)
        ->log_debug_is('User lacks the required role (rw) for device '.$located_device_id);

    $t->authenticate(email => $rw_user->email);

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { key => 'value' })
        ->status_is(204);
    $t->post_ok('/device/LOCATED_DEVICE/settings/key', json => { key => 'new value' })
        ->status_is(403)
        ->log_debug_is('User lacks the required role (admin) for device '.$located_device_id);
    $t->delete_ok('/device/LOCATED_DEVICE/settings/foo')
        ->status_is(403)
        ->log_debug_is('User lacks the required role (admin) for device '.$located_device_id);

    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { key => 'new value', 'tag.bar' => 'bar' })
        ->status_is(403)
        ->log_debug_is('User lacks the required role (admin) for device '.$located_device_id);
    $t->post_ok('/device/LOCATED_DEVICE/settings', json => { 'tag.foo' => 'foo', 'tag.bar' => 'bar' })
        ->status_is(204);

    $t->post_ok('/device/LOCATED_DEVICE/settings/tag.bar', json => { 'tag.bar' => 'newbar' })
        ->status_is(204);
    $t->get_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(200)
        ->json_schema_is('DeviceSetting')
        ->json_is('/tag.bar', 'newbar', 'Setting was updated');
    $t->delete_ok('/device/LOCATED_DEVICE/settings/tag.bar')
        ->status_is(204);
    $t->get_ok('/device/LOCATED_DEVICE/settings/tag.bar')
};

subtest 'Device PXE' => sub {
    my $t_super = Test::Conch->new(pg => $t->pg, fixtures => $t->fixtures);
    $t_super->authenticate(email => $super_user->email);
    my $layout = $t_super->load_fixture('rack_0a_layout_3_6');

    my $device_pxe = $t_super->app->db_devices->create({
        serial_number => 'PXE_TEST',
        hardware_product_id => $layout->hardware_product_id,
        health => 'unknown',
        device_relay_connections => [{
            relay => {
                serial_number => 'my_relay',
                user_id => $super_user->id,
            }
        }],
        device_nics => [
            {
                state => 'up',
                iface_name => 'milhouse',
                iface_type => 'human',
                iface_vendor => 'Groening',
                mac => '00:00:00:00:00:aa',
                ipaddr => '0.0.0.1',
            },
            {
                state => 'up',
                iface_name => 'ned',
                iface_type => 'human',
                iface_vendor => 'Groening',
                mac => '00:00:00:00:00:bb',
                ipaddr => '0.0.0.2',
            },
            {
                state => undef,
                iface_name => 'ipmi1',
                iface_type => 'human',
                iface_vendor => 'Groening',
                mac => '00:00:00:00:00:cc',
                ipaddr => '0.0.0.3',
            },
        ],
    });

    $t_super->get_ok('/device/PXE_TEST/pxe')
        ->status_is(200)
        ->json_schema_is('DevicePXE')
        ->json_is({
            id => $device_pxe->id,
            phase => 'integration',
            location => undef,
            ipmi => {
                mac => '00:00:00:00:00:cc',
                ip => '0.0.0.3',
            },
            pxe => {
                mac => '00:00:00:00:00:aa',
            },
        });

    $layout->create_related('device_location', { device_id => $device_pxe->id });
    my $datacenter = $t_super->load_fixture('datacenter_0');

    my $t_ro = Test::Conch->new(pg => $t_super->pg);
    $t_ro->authenticate(email => $ro_user->email);

    $t_ro->get_ok('/device/PXE_TEST/pxe')
        ->status_is(200)
        ->json_schema_is('DevicePXE')
        ->json_cmp_deeply({
            id => $device_pxe->id,
            phase => 'integration',
            location => {
                az => 'room-0a',
                datacenter_room => 'room 0a',
                rack => 'ROOM:0.A:rack.0a',
                rack_unit_start => 3,
                target_hardware_product => superhashof({ alias => $layout->hardware_product->alias }),
            },
            ipmi => {
                mac => '00:00:00:00:00:cc',
                ip => '0.0.0.3',
            },
            pxe => {
                mac => '00:00:00:00:00:aa',
            },
        });
    my $pxe_data = $t_ro->tx->res->json;

    $device_pxe->update({ phase => 'production' });
    delete $pxe_data->{location};

    $t_super->get_ok('/device/PXE_TEST/pxe')
        ->status_is(409)
        ->location_is('/device/'.$device_pxe->id.'/links')
        ->json_is({ error => 'device is in the production phase' });

    $t_super->get_ok('/device/PXE_TEST/pxe?phase_earlier_than=')
        ->status_is(200)
        ->json_schema_is('DevicePXE')
        ->json_is({ $pxe_data->%*, phase => 'production' });

    $device_pxe->update({ phase => 'integration' });
    $device_pxe->delete_related('device_location');
    $device_pxe->delete_related('device_nics');

    $t_ro->get_ok('/device/PXE_TEST/pxe')
        ->status_is(403)
        ->log_debug_is('User lacks the required role (ro) for device '.$device_pxe->id);

    $t_super->get_ok('/device/PXE_TEST/pxe')
        ->status_is(200)
        ->json_schema_is('DevicePXE')
        ->json_is({
            id => $device_pxe->id,
            phase => 'integration',
            location => undef,
            ipmi => undef,
            pxe => undef,
        });
};

subtest 'Device location' => sub {
    my $t_rw = Test::Conch->new(pg => $t->pg);
    $t_rw->authenticate(email => $rw_user->email);

    $t_rw->post_ok('/device/TEST/location')
        ->status_is(403)
        ->log_debug_is('User lacks the required role (rw) for device '.$test_device_id);

    $t_rw->delete_ok('/device/TEST/location')
        ->status_is(403)
        ->log_debug_is('User lacks the required role (rw) for device '.$test_device_id);

    my $t_build = Test::Conch->new(pg => $t->pg);
    $t_build->authenticate(email => $build_user->email);

    # TODO? possibly we should be able to set the location if the user has permission to
    # access the target location of the device.
    $t_build->post_ok('/device/TEST/location')
        ->status_is(400)
        ->json_schema_is('RequestValidationError')
        ->json_cmp_deeply('/details', [ { path => '/', message => re(qr/expected object/i) } ]);

    $t_build->post_ok('/device/TEST/location', json => { rack_id => $rack_id, rack_unit_start => 42 })
        ->status_is(409)
        ->json_is({ error => "slot 42 does not exist in the layout for rack $rack_id" });

    # make sure device is using the Storage sku
    $t_build->app->db_devices->search({ id => $test_device_id })
        ->update({ hardware_product_id => $hardware_product2->id });

    # now move device back to a Compute rack_unit
    $t_build->post_ok('/device/TEST/location', json => { rack_id => $rack_id, rack_unit_start => 1 })
        ->status_is(303)
        ->location_is('/device/'.$test_device_id.'/location');

    $t_build->get_ok('/device/TEST/location')
        ->status_is(200)
        ->json_schema_is('DeviceLocation')
        ->json_cmp_deeply({
            az => $rack->datacenter_room->az,
            datacenter_room => $rack->datacenter_room->alias,
            rack => $rack->datacenter_room->vendor_name.':'.$rack->name,
            rack_unit_start => 1,
            target_hardware_product => {
                (map +($_ => $hardware_product->$_), qw(id name alias sku hardware_vendor_id)),
            },
        });
    my $location_data = $t_build->tx->res->json;

    $t->get_ok('/device/TEST')
        ->status_is(200)
        ->json_schema_is('DetailedDevice')
        ->json_cmp_deeply({
            $detailed_device->%*,
            hardware_product_id => $hardware_product->id,
            sku => $hardware_product->sku,
            health => 'unknown',
            updated => ignore,
            location => $location_data,
        });

    $t_build->app->db_devices->search({ id => $test_device_id })->update({ phase => 'production' });

    $t_build->get_ok('/device/TEST/location')
        ->status_is(409)
        ->location_is('/device/'.$test_device_id.'/links')
        ->json_is({ error => 'device is in the production phase' });

    $t_build->get_ok('/device/TEST/location?phase_earlier_than=')
        ->status_is(200)
        ->json_schema_is('DeviceLocation')
        ->json_is($location_data);

    $t_build->delete_ok('/device/TEST/location')
        ->status_is(409)
        ->location_is('/device/'.$test_device_id.'/links')
        ->json_is({ error => 'device is in the production phase' });

    $t_build->app->db_devices->search({ id => $test_device_id })->update({ phase => 'installation' });

    $t_rw->delete_ok('/device/TEST/location')
        ->status_is(204);

    # rw user has lost access to the device because it no longer has a location
    $t_rw->post_ok('/device/TEST/location', json => { rack_id => $rack_id, rack_unit_start => 3 })
        ->status_is(403);
};

done_testing;
# vim: set ts=4 sts=4 sw=4 et :
