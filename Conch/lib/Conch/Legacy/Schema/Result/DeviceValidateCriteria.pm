use utf8;

package Conch::Legacy::Schema::Result::DeviceValidateCriteria;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::Legacy::Schema::Result::DeviceValidateCriteria

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

=head1 TABLE: C<device_validate_criteria>

=cut

__PACKAGE__->table("device_validate_criteria");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  default_value: gen_random_uuid()
  is_nullable: 0
  size: 16

=head2 product_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 1
  size: 16

=head2 component

  data_type: 'text'
  is_nullable: 0

=head2 condition

  data_type: 'text'
  is_nullable: 0

=head2 vendor

  data_type: 'text'
  is_nullable: 1

=head2 model

  data_type: 'text'
  is_nullable: 1

=head2 string

  data_type: 'text'
  is_nullable: 1

=head2 min

  data_type: 'integer'
  is_nullable: 1

=head2 warn

  data_type: 'integer'
  is_nullable: 1

=head2 crit

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type     => "uuid",
    default_value => \"gen_random_uuid()",
    is_nullable   => 0,
    size          => 16,
  },
  "product_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 1, size => 16 },
  "component",
  { data_type => "text", is_nullable => 0 },
  "condition",
  { data_type => "text", is_nullable => 0 },
  "vendor",
  { data_type => "text", is_nullable => 1 },
  "model",
  { data_type => "text", is_nullable => 1 },
  "string",
  { data_type => "text", is_nullable => 1 },
  "min",
  { data_type => "integer", is_nullable => 1 },
  "warn",
  { data_type => "integer", is_nullable => 1 },
  "crit",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 product

Type: belongs_to

Related object: L<Conch::Legacy::Schema::Result::HardwareProductProfile>

=cut

__PACKAGE__->belongs_to(
  "product",
  "Conch::Legacy::Schema::Result::HardwareProductProfile",
  { id => "product_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

# Created by DBIx::Class::Schema::Loader v0.07047 @ 2018-01-12 11:35:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KObyA+TauhtmNMSRmMFYcQ

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

