package Conch::Plugin::Database;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Conch::Pg;
use Conch::DB ();
use Lingua::EN::Inflexion 'noun';

=pod

=head1 NAME

Conch::Plugin::Database

=head1 DESCRIPTION

Sets up the database and provides convenient accessors to it.

=head1 HELPERS

=cut

sub register ($self, $app, $config) {

    # legacy database access; will be removed soon.
    my $db = Conch::Pg->new($config->{pg});
    my ($dsn, $username, $password) = ($db->dsn, $db->username, $db->password);

    # cache the schema objects so we share connections between multiple $c->schema calls,
    # e.g. for transaction management.  These are closed over in the subs below, so they
    # persist for the lifetime of the $app.
    my ($_rw_schema, $_ro_schema);

=head2 schema

Provides read/write access to the database via L<DBIx::Class>.  Returns a L<Conch::DB> object.

=cut

    $app->helper(schema => sub {
        return $_rw_schema if $_rw_schema;
        $_rw_schema = Conch::DB->connect(
            $dsn, $username, $password,
        );
    });

=head2 rw_schema

See L</schema>.

=cut

    $app->helper(rw_schema => $app->renderer->get_helper('schema'));

=head2 ro_schema

Provides (guaranteed) read-only access to the database via L<DBIx::Class>.  Returns a
L<Conch::DB> object.

Note that because of the use of C<< AutoCommit => 0 >>, database errors must be explicitly
cleared with C<< ->txn_rollback >>; see L<DBD::Pg/"ReadOnly-(boolean)">.

=cut

    $app->helper(ro_schema => sub {
        return $_ro_schema if $_ro_schema;
        $_ro_schema = Conch::DB->connect(sub {
            DBI->connect(
                $dsn, $username, $password,
                {
                    ReadOnly            => 1,
                    AutoCommit          => 0,
                    AutoInactiveDestroy => 1,
                    PrintError          => 0,
                    PrintWarn           => 0,
                    RaiseError          => 1,
                });
        });
    });

=head2 db_<table>s, db_ro_<table>s

Provides direct read/write and read-only accessors to resultsets.  The table name is used in
the C<alias> attribute (see L<DBIx::Class::ResultSet/alias>).

=cut

    # db_user_accounts => $app->schema->resultset('user_account'), etc
    # db_ro_user_accounts => $app->ro_schema->resultset('user_account'), etc
    foreach my $source_name ($app->schema->sources) {
        my $plural = noun($source_name)->plural;
        $app->helper('db_'.$plural, sub {
            my $source = $_[0]->app->schema->source($source_name);
            # note that $source_name eq $source->from unless we screwed up.
            $source->resultset->search({}, { alias => $source->from });
        });
        $app->helper('db_ro_'.$plural, sub {
            my $ro_source = $_[0]->app->ro_schema->source($source_name);
            $ro_source->resultset->search({}, { alias => $ro_source->from });
        });
    }

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
# vim: set ts=4 sts=4 sw=4 et :
