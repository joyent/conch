use utf8;
package Conch::DB::Result::UserAccount;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::DB::Result::UserAccount

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::Helper::Row::ToJSON>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp", "Helper::Row::ToJSON");

=head1 TABLE: C<user_account>

=cut

__PACKAGE__->table("user_account");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  default_value: gen_random_uuid()
  is_nullable: 0
  size: 16

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 password_hash

  data_type: 'text'
  is_nullable: 0

=head2 created

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 last_login

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 email

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "uuid",
    default_value => \"gen_random_uuid()",
    is_nullable => 0,
    size => 16,
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "password_hash",
  { data_type => "text", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_login",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "email",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<user_account_email_key>

=over 4

=item * L</email>

=back

=cut

__PACKAGE__->add_unique_constraint("user_account_email_key", ["email"]);

=head2 C<user_account_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("user_account_name_key", ["name"]);

=head1 RELATIONS

=head2 user_relay_connections

Type: has_many

Related object: L<Conch::DB::Result::UserRelayConnection>

=cut

__PACKAGE__->has_many(
  "user_relay_connections",
  "Conch::DB::Result::UserRelayConnection",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_session_tokens

Type: has_many

Related object: L<Conch::DB::Result::UserSessionToken>

=cut

__PACKAGE__->has_many(
  "user_session_tokens",
  "Conch::DB::Result::UserSessionToken",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_settings

Type: has_many

Related object: L<Conch::DB::Result::UserSetting>

=cut

__PACKAGE__->has_many(
  "user_settings",
  "Conch::DB::Result::UserSetting",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_workspace_roles

Type: has_many

Related object: L<Conch::DB::Result::UserWorkspaceRole>

=cut

__PACKAGE__->has_many(
  "user_workspace_roles",
  "Conch::DB::Result::UserWorkspaceRole",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-07-20 14:29:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/ob4MGQbDk0L0sqGUZ2EpA

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut
