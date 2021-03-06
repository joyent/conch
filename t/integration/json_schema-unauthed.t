use strict;
use warnings;

use Test::Conch;
use Test::More;
use Test::Warnings;
use Mojo::JSON 'decode_json';
use Path::Tiny 'path';
use Test::Deep;
use Test::Fatal;
use Conch::UUID 'create_uuid_str';

use constant SPEC_URL => 'https://json-schema.org/draft/2019-09/schema';

my $t = Test::Conch->new(pg => undef);
my $base_uri = $t->ua->server->url; # used as the base uri for all requests

$t->get_ok('/schema/request/foo')
    ->status_is(308)
    ->location_is('/json_schema/request/Foo')
    ->header_is('X-Deprecated', 'this endpoint was deprecated and removed in api v3.1');

$t->get_ok('/schema/REQUEST/hello')
    ->status_is(404)
    ->json_is({ error => 'Route Not Found' })
    ->log_warn_is('no endpoint found for: GET /schema/REQUEST/hello');

$t->get_ok('/json_schema/request/b~a!!r')
    ->status_is(404)
    ->json_is({ error => 'Route Not Found' });

$t->get_ok('/json_schema/request/Hello')
    ->status_is(404)
    ->log_warn_is('Could not find request schema Hello');

$t->get_ok('/json_schema/response/Ping' => { 'If-Modified-Since' => 'Sun, 01 Jan 2040 00:00:00 GMT' })
    ->status_is(304)
    ->header_is('Last-Modified', $t->app->startup_time->strftime('%a, %d %b %Y %T GMT'));

$t->get_ok('/json_schema/response/Ping' => { 'If-Modified-Since' => 'Sun, 01 Jan 2006 00:00:00 GMT' })
    ->status_is(200)
    ->header_is('Last-Modified', $t->app->startup_time->strftime('%a, %d %b %Y %T GMT'))
    ->header_is('Content-Type', 'application/schema+json')
    ->header_is('Link', '</json_schema/response/JSONSchemaOnDisk>; rel="describedby"')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply({
        '$schema' => SPEC_URL,
        '$id' => $base_uri.'json_schema/response/Ping',
        type => 'object',
        additionalProperties => JSON::PP::false,
        required => ['status'],
        properties => { status => { const => 'ok' } },
    });

$t->get_ok('/schema/response/login_token')
    ->status_is(308)
    ->header_is('X-Deprecated', 'this endpoint was deprecated and removed in api v3.1')
    ->location_is('/json_schema/response/LoginToken');

$t->get_ok('/json_schema/response/login_token')
    ->status_is(404);

$t->ua->max_redirects(10);
$t->get_ok('/schema/response/login_token')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply(my $response_login_token = {
        '$schema' => SPEC_URL,
        '$id' => $base_uri.'json_schema/response/LoginToken',
        type => 'object',
        additionalProperties => JSON::PP::false,
        required => ['jwt_token'],
        properties => { jwt_token => {
            type => 'string',
            pattern => '^[^.]+\.[^.]+\.[^.]+$',
            contentMediaType => 'application/jwt',
        } },
    });
$t->ua->max_redirects(0);

$t->get_ok('/json_schema/response/LoginToken')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply($response_login_token);

$t->get_ok('/json_schema/request/Login')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply({
        '$schema' => SPEC_URL,
        '$id' => $base_uri.'json_schema/request/Login',
        type => 'object',
        unevaluatedProperties => JSON::PP::false,
        required => [ 'password' ],
        properties => {
            password => { title => 'Password', writeOnly => JSON::PP::true, '$ref' => '/json_schema/common/non_empty_string' },
            set_session => { type => 'boolean' },
        },
        '$ref' => '/json_schema/request/UserIdOrEmail',
        '$defs' => {
            non_empty_string => {
              '$id' => '/json_schema/common/non_empty_string',
              type => 'string',
              minLength => 1,
            },
            uuid => superhashof({
              '$id' => '/json_schema/common/uuid',
            }),
            email_address => superhashof({
              '$id' => '/json_schema/common/email_address',
              '$ref' => '/json_schema/common/mojo_relaxed_placeholder',
            }),
            mojo_relaxed_placeholder => superhashof({ '$id' => '/json_schema/common/mojo_relaxed_placeholder' }),
            UserIdOrEmail => {
                '$id' => '/json_schema/request/UserIdOrEmail',
                type => 'object',
                additionalProperties => JSON::PP::true,
                oneOf => [ { required => [ 'user_id' ] }, { required => [ 'email' ] } ],
                properties => {
                    user_id => { '$ref' => '/json_schema/common/uuid' },
                    email => { '$ref' => '/json_schema/common/email_address' },
                },
            },
        },
        default => { set_session => JSON::PP::false },
    });

$t->get_ok('/json_schema/query_params/ResetUserPassword')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply({
        '$schema' => SPEC_URL,
        '$id' => $base_uri.'json_schema/query_params/ResetUserPassword',
        '$defs' => {
            boolean_string => {
                '$id' => '/json_schema/query_params/boolean_string',
                type => 'string', enum => [ '0', '1' ],
            },
        },
        type => 'object',
        additionalProperties => JSON::PP::false,
        properties => {
            clear_tokens => { enum => [ qw(none login_only all) ] },
            send_mail => { '$ref' => '/json_schema/query_params/boolean_string' },
        },
        default => {
            clear_tokens => 'login_only',
            send_mail => '1',
        },
    });

$t->get_ok('/json_schema/request/HardwareProductUpdate')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply('', superhashof({
      '$schema' => SPEC_URL,
      '$id' => $base_uri.'json_schema/request/HardwareProductUpdate',
      properties => superhashof({
        specification => {
          title => 'Specification',
          type => 'object',
          # note this reference is not expanded into $defs
          '$ref' => '/json_schema/hardware_product/specification/latest',
        },
      }),
    }), 'reference to hardware_product specification is retained');

$t->get_ok('/json_schema/response/JSONSchemaOnDisk')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply({
        '$schema' => SPEC_URL,
        '$id' => $base_uri.'json_schema/response/JSONSchemaOnDisk',
        '$comment' => ignore,
        contentMediaType => 'application/schema+json',
        allOf => [
          {
            '$comment' => ignore,
            '$id' => ignore,  # we just need there to be something here
            '$ref' => SPEC_URL,
            '$recursiveAnchor' => JSON::PP::true,
            '$ref' => SPEC_URL,
            properties => {
              '$schema' => { const => SPEC_URL },
            },
            unevaluatedProperties => JSON::PP::false,
          },
          {
            '$comment' => ignore,
            type => ignore,
            required => [ '$id', '$schema' ],
            properties => ignore,
          },
        ],
    });

$t->get_ok('/json_schema/response/JSONSchema')
  ->status_is(200)
  ->header_is('Content-Type', 'application/schema+json')
  ->json_schema_is('JSONSchemaOnDisk')
  ->json_cmp_deeply({
    '$schema' => SPEC_URL,
    '$id' => $base_uri.'json_schema/response/JSONSchema',
    '$comment' => ignore,
    contentMediaType => 'application/schema+json',
    allOf => [
      {
        '$comment' => ignore,
        '$id' => ignore,  # we just need there to be something here
        '$ref' => SPEC_URL,
        '$recursiveAnchor' => JSON::PP::true,
        '$ref' => SPEC_URL,
        properties => {
          '$schema' => { const => SPEC_URL },
          'x-json_schema_id' => { '$ref' => '/json_schema/common/uuid' },
        },
        unevaluatedProperties => JSON::PP::false,
      },
      {
        '$comment' => ignore,
        type => ignore,
        required => [ '$id', '$schema', '$comment', 'description', 'x-json_schema_id' ],
        properties => ignore,
      },
    ],
    '$defs' => {
      uuid => superhashof({}),
      non_empty_string => {
        '$id' => '/json_schema/common/non_empty_string',
        type => 'string',
        minLength => 1,
      },
    },
  });

$t->get_ok('/json_schema/request/DeviceReport')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply(superhashof({
        '$schema' => SPEC_URL,
        '$id' => re(qr{/json_schema/request/DeviceReport$}),
        '$ref' => '/json_schema/device_report/DeviceReport_v3_2_0',
        '$defs' => superhashof({
            'DeviceReport_v3_2_0' => superhashof({
                '$comment' => ignore,
                '$id' => '/json_schema/device_report/DeviceReport_v3_2_0',
                properties => superhashof({}),
                required => superbagof(),
            }),
       }),
    }));

$t->get_ok('/json_schema/common/non_zero_uuid')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply({
        '$id' => $base_uri.'json_schema/common/non_zero_uuid',
        '$schema' => SPEC_URL,
        '$ref' => '/json_schema/common/uuid',
        not => { const => '00000000-0000-0000-0000-000000000000' },
        '$defs' => {
            uuid => {
                '$id' => '/json_schema/common/uuid',
                type => 'string', pattern => ignore,
            },
        },
    });

$t->get_ok('/json_schema/device_report/DeviceReport_v3_2_0')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply({
        '$id' => $base_uri.'json_schema/device_report/DeviceReport_v3_2_0',
        '$schema' => SPEC_URL,
        '$comment' => ignore,
        type => 'object',
        additionalProperties => JSON::PP::true,
        required => ignore,
        properties => superhashof({}),
        '$defs' => {
            map +($_ => superhashof({})),
                qw(non_empty_string int_or_stringy_int disk_serial_number device_interface_name macaddr ipaddr relay_serial_number device_serial_number non_zero_uuid links uuid mojo_standard_placeholder mojo_relaxed_placeholder),
        },
    });

my $schema = $t->tx->res->json;

# ensure that one of the schemas can validate some data
{
    my $report = decode_json(path('t/integration/resource/passing-device-report.json')->slurp_raw);
    my $result = $t->app->json_schema_validator->evaluate($report, $schema);
    ok($result, 'no errors')
      or diag 'got errors: ', explain($result->TO_JSON);
}

subtest 'schemas that contain an unresolvable $ref property because it is not a keyword' => sub {
  # hack a schema to contain something that looks like a $ref but isn't...
  # In the future we can also test this more sanely with:
  # POST /json_schema/foo/bar <new schema>
  # GET /json_schema/foo/bar/latest?with_bundled_refs=1
  # we don't do $js->get(..) because that clones the data.
  my $schema_data = $t->app->json_schema_validator->{_resource_index}{'response.yaml'}{document}{schema};

  $schema_data->{'$defs'}{MyNewSchema} = {
    type => 'object',
    properties => {
      '$ref' => {
        type => 'string',
        format => 'uri',
      },
      other_property => {
        const => { '$ref' => 'just a string, not a ref!' },
      },
    },
  };

  $t->get_ok('/json_schema/response/MyNewSchema')
    ->status_is(200)
    ->header_is('Content-Type', 'application/schema+json')
    ->json_schema_is('JSONSchemaOnDisk')
    ->json_cmp_deeply(superhashof({
        '$schema' => SPEC_URL,
        '$id' => re(qr{/json_schema/response/MyNewSchema$}),
        type => 'object',
        properties => {
          '$ref' => {
            type => 'string',
            format => 'uri',
          },
          other_property => {
            const => { '$ref' => 'just a string, not a ref!' },
          },
        },
    }));
};


{
  # we need a working database connection for these tests
  my $t = Test::Conch->new;

  $t->post_ok('/json_schema/foo/bar', json => {})
    ->status_is(401);

  $t->get_ok($_)->status_is(401)
    foreach
      '/json_schema/'.create_uuid_str,
      '/json_schema/foo',
      '/json_schema/foo/bar',
      '/json_schema/foo/bar/1',
      '/json_schema/foo/bar/latest';

  $t->delete_ok($_)->status_is(401)
    foreach
      '/json_schema/'.create_uuid_str,
      '/json_schema/foo/bar/1';

  $t->get_ok('/json_schema/hardware_product/specification/'.$_)
      ->status_is(401)
    foreach qw(latest 1);
}

done_testing;
# vim: set sts=2 sw=2 et :
