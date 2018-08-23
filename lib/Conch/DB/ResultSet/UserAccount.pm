package Conch::DB::ResultSet::UserAccount;
use v5.20;
use warnings;
use parent 'DBIx::Class::ResultSet';

use Conch::UUID 'is_uuid';

=head1 DESCRIPTION

Interface to queries against the 'user_account' table.

=head2 create

This method is built in to all resultsets.  In Conch::DB::Result::UserAccount we have overrides
allowing us to receive the 'password' key, which we hash into 'password_hash'.

    $c->schema->resultset('UserAccount') or $c->db_user_accounts
    ->create({
        name => ...,        # required, but usually the same as email :/
        email => ...,       # required
        password => ...,    # required, if password_hash not provided
    });

=cut

=head2 update

This method is built in to all resultsets.  In Conch::DB::Result::UserAccount we have overrides
allowing us to receive the 'password' key, which we hash into 'password_hash'.

    $c->schema->resultset('UserAccount') or $c->db_user_accounts
    ->update({
        password => ...,
        ... possibly other things
    });

=cut

=head2 lookup_by_id

=cut

sub lookup_by_id {
    my ($self, $user_id) = @_;
    return if not is_uuid($user_id);    # avoid pg exception "invalid input syntax for uuid"
    $self->active->find({ id => $user_id });
}

=head2 lookup_by_email

Returns the user with the (case-insensitively) matching email.

If more than one is found, we return the one created most recently, and a warning will be
logged (via DBIx::Class::ResultSet::single).

=cut

sub lookup_by_email {
    my ($self, $email) = @_;

    $self->active->search(
        [ \[ 'lower(email) = lower(?)', $email ] ],
        { order_by => { -desc => 'created' }, rows => 1 },
    )->first;
}

=head2 lookup_by_name

=cut

sub lookup_by_name {
    my ($self, $name) = @_;
    $self->active->find({ name => $name });
}

=head2 active

Chainable resultset to limit results to those that aren't deactivated.
TODO: move to a role 'Deactivatable'

=cut

sub active {
    my $self = shift;

    $self->search({ deactivated => undef });
}

=head2 deactivate

Update all matching rows by setting deactivated = NOW().
TODO: move to a role 'Deactivatable'

=cut

sub deactivate {
    my $self = shift;

    $self->update({ deactivated => \'NOW()' });
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
