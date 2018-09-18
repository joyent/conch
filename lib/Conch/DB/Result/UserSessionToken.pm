use utf8;
package Conch::DB::Result::UserSessionToken;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::DB::Result::UserSessionToken

=cut

use strict;
use warnings;


=head1 BASE CLASS: L<Conch::DB::Result>

=cut

use base 'Conch::DB::Result';

=head1 TABLE: C<user_session_token>

=cut

__PACKAGE__->table("user_session_token");

=head1 ACCESSORS

=head2 user_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 token_hash

  data_type: 'bytea'
  is_nullable: 0

=head2 expires

  data_type: 'timestamp with time zone'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "token_hash",
  { data_type => "bytea", is_nullable => 0 },
  "expires",
  { data_type => "timestamp with time zone", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</user_id>

=item * L</token_hash>

=back

=cut

__PACKAGE__->set_primary_key("user_id", "token_hash");

=head1 RELATIONS

=head2 user_account

Type: belongs_to

Related object: L<Conch::DB::Result::UserAccount>

=cut

__PACKAGE__->belongs_to(
  "user_account",
  "Conch::DB::Result::UserAccount",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-09-17 14:52:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3duPGO9UY9pz/5QRI2IGiQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut
