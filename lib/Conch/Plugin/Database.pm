package Conch::Plugin::Database;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Conch::DB ();
use Lingua::EN::Inflexion 'noun';
use Try::Tiny;
use Conch::DB::Util;
use Safe::Isa;

=pod

=head1 NAME

Conch::Plugin::Database

=head1 DESCRIPTION

Sets up the database and provides convenient accessors to it.

=head1 HELPERS

These methods are made available on the C<$c> object (the invocant of all controller methods,
and therefore other helpers).

=cut

sub register ($self, $app, $config) {

    # hashref containing dsn, username, password, options, ro_username, ro_password
    my $db_credentials = Conch::DB::Util::get_credentials($config->{database}, $app->log);


=head2 schema

Provides read/write access to the database via L<DBIx::Class>. Returns a L<Conch::DB> object
that persists for the lifetime of the application.

=cut

    my $_rw_schema;
    $app->helper(schema => sub ($c) {
        return $_rw_schema if $_rw_schema;
        my $app_name = join(' ', $c->app->moniker, ($ARGV[0] // ()), $c->version_tag, '('.$$.')');
        $_rw_schema = Conch::DB->connect(
            $db_credentials->@{qw(dsn username password)},
            +{
                $db_credentials->{options}->%*,
                on_connect_do => [ q{set application_name to '}.$app_name.q{'} ],
            },
        );
    });

=head2 rw_schema

See L</schema>; can be used interchangeably with it.

=cut

    $app->helper(rw_schema => $app->renderer->get_helper('schema'));

=head2 ro_schema

Provides (guaranteed) read-only access to the database via L<DBIx::Class>. Returns a
L<Conch::DB> object that persists for the lifetime of the application.

=cut

    my $_ro_schema;
    $app->helper(ro_schema => sub ($c) {
        return $_ro_schema if $_ro_schema;
        my $app_name = join(' ', $c->app->moniker, ($ARGV[0] // ()), $c->version_tag, '('.$$.')');
        $_ro_schema = Conch::DB->connect(
            $db_credentials->@{qw(dsn ro_username ro_password)},
            +{
                $db_credentials->{options}->%*,
                on_connect_do => [ q{set application_name to '}.$app_name.q{'} ],
            },
        );
    });

=head2 db_<table>s, db_ro_<table>s

Provides direct read/write and read-only accessors to resultsets. The table name is used in
the C<alias> attribute (see L<DBIx::Class::ResultSet/alias>).

=cut

    # db_user_accounts => $app->schema->resultset('user_account'), etc
    # db_ro_user_accounts => $app->ro_schema->resultset('user_account'), etc
    foreach my $source_name ($app->schema->sources) {
        my $plural = noun($source_name)->plural;

        $app->helper('db_'.$plural, sub ($c) {
            my $source = $c->schema->source($source_name);
            # note that $source_name eq $source->from unless we screwed up.
            $source->resultset->search(undef, { alias => $source->from });
        });

        $app->helper('db_ro_'.$plural, sub ($c) {
            my $ro_source = $c->ro_schema->source($source_name);
            $ro_source->resultset->search(undef, { alias => $ro_source->from });
        });
    }

=head2 txn_wrapper

    my $result = $c->txn_wrapper(sub ($c) {
        # many update, delete queries etc...
    });

    # if the result is false, we errored and rolled back the db...
    return $c->status(400) if not $result;

Wraps the provided subref in a database transaction, rolling back in case of an exception.
Any provided arguments are passed to the sub, along with the invocant controller.

If the exception is not C<'rollback'> (which signals an intentional premature bailout), the
exception will be logged and stored in the stash, of which the first line will be included in
the response if no other response is prepared (see L<Conch/status>).

You should B<not> render a response in the subref itself, as you will have a difficult time
figuring out afterwards whether C<< $c->rendered >> still needs to be called or not. Instead,
use the subref's return value to signal success.

=cut

    $app->helper(txn_wrapper => sub ($c, $subref, @args) {
        # suppress warning generated by rollback-after-commit via deferred constraint
        # violation -- see https://rt.cpan.org/Ticket/Display.html?id=129816
        my $old_sig_warn = $SIG{__WARN__};
        local $SIG{__WARN__} = sub {
            return if $_[0] =~ /^rollback ineffective with AutoCommit enabled/;
            goto &$old_sig_warn if $old_sig_warn;
        };
        try {
            # we don't do anything else here, so as to preserve context and the return value
            # for the original caller.
            $c->schema->txn_do($subref, $c, @args);
        }
        catch {
            my $exception = $_;
            $c->log->debug('rolled back transaction');
            if ($exception !~ /^rollback/) {
                $c->stash('exception',
                    ($exception->$_isa('Mojo::Exception') ? $exception
                        : Mojo::Exception->new($exception))->inspect);
                $c->log->error($c->log->is_level('debug') ? $exception : (split(/\n/, $exception, 2))[0]);
            }
            return;
        };
    });

    return if $app->feature('no_db');


    # verify that we are running the version of postgres we expect...
    my $pgsql_version = Conch::DB::Util::get_postgres_version($app->schema);
    $app->log->info($db_credentials->{dsn}.' running '.$pgsql_version);

    use constant POSTGRES_MINIMUM_VERSION_MAJOR => 10;
    use constant POSTGRES_MINIMUM_VERSION_MINOR => 10;

    # at present we do all testing on 10.x so that is the most preferred configuration, but we
    # are not aware of any issues on PostgreSQL 11.x.
    my ($major, $minor, $rest) = $pgsql_version =~ /PostgreSQL (\d+)\.(\d+)(\.\d+)?\b/;
    $minor //= 0;
    $rest //= '';
    $app->log->warn('Running '.$major.'.'.$minor.$rest.', expected at least '
            .POSTGRES_MINIMUM_VERSION_MAJOR.'.'.POSTGRES_MINIMUM_VERSION_MINOR.'!')
        if $major < POSTGRES_MINIMUM_VERSION_MAJOR
            or $major == POSTGRES_MINIMUM_VERSION_MAJOR and $minor < POSTGRES_MINIMUM_VERSION_MINOR;


    my ($latest_migration, $expected_latest_migration) = Conch::DB::Util::get_migration_level($app->schema);
    $app->log->debug("Latest database migration number: $latest_migration");
    if ($latest_migration != $expected_latest_migration) {
        my $message = "Latest migration that has been run is $latest_migration, but latest on disk is $expected_latest_migration!";
        $app->log->fatal($message);
        die $message;
    }
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
