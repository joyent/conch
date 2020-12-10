use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::Conch;

my $t = Test::Conch->new(pg => undef);

like($t->app->version_tag, qr/^v\d+\.\d+(?:\.\d+(.*))?-\d+-g[[:xdigit:]]+$/, 'got the version tag');

like($t->app->version_hash, qr/^[[:xdigit:]]+$/, 'got the version hash');

done_testing;
# vim: set sts=2 sw=2 et :
