use utf8;

package Conch::Legacy::Schema::Result::DeviceRelayConnection;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::Legacy::Schema::Result::DeviceRelayConnection

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=back

=cut

__PACKAGE__->load_components( "InflateColumn::DateTime", "TimeStamp" );

=head1 TABLE: C<device_relay_connection>

=cut

__PACKAGE__->table("device_relay_connection");

=head1 ACCESSORS

=head2 device_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 relay_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 first_seen

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 last_seen

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "device_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "relay_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "first_seen",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_seen",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</device_id>

=item * L</relay_id>

=back

=cut

__PACKAGE__->set_primary_key( "device_id", "relay_id" );

=head1 RELATIONS

=head2 device

Type: belongs_to

Related object: L<Conch::Legacy::Schema::Result::Device>

=cut

__PACKAGE__->belongs_to(
  "device",
  "Conch::Legacy::Schema::Result::Device",
  { id            => "device_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 relay

Type: belongs_to

Related object: L<Conch::Legacy::Schema::Result::Relay>

=cut

__PACKAGE__->belongs_to(
  "relay",
  "Conch::Legacy::Schema::Result::Relay",
  { id            => "relay_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

# Created by DBIx::Class::Schema::Loader v0.07047 @ 2018-01-12 11:35:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:F70oRHdjl1Nq8G5hott4Iw

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

__DATA__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License, 
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut

