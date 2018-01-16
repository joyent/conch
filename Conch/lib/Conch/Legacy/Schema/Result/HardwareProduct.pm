use utf8;

package Conch::Legacy::Schema::Result::HardwareProduct;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::Legacy::Schema::Result::HardwareProduct

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

=head1 TABLE: C<hardware_product>

=cut

__PACKAGE__->table("hardware_product");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  default_value: gen_random_uuid()
  is_nullable: 0
  size: 16

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 alias

  data_type: 'text'
  is_nullable: 0

=head2 prefix

  data_type: 'text'
  is_nullable: 1

=head2 vendor

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 deactivated

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 created

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 updated

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type     => "uuid",
    default_value => \"gen_random_uuid()",
    is_nullable   => 0,
    size          => 16,
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "alias",
  { data_type => "text", is_nullable => 0 },
  "prefix",
  { data_type => "text", is_nullable => 1 },
  "vendor",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "deactivated",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<hardware_product_alias_key>

=over 4

=item * L</alias>

=back

=cut

__PACKAGE__->add_unique_constraint( "hardware_product_alias_key", ["alias"] );

=head2 C<hardware_product_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint( "hardware_product_name_key", ["name"] );

=head1 RELATIONS

=head2 datacenter_rack_layouts

Type: has_many

Related object: L<Conch::Legacy::Schema::Result::DatacenterRackLayout>

=cut

__PACKAGE__->has_many(
  "datacenter_rack_layouts",
  "Conch::Legacy::Schema::Result::DatacenterRackLayout",
  { "foreign.product_id" => "self.id" },
  { cascade_copy         => 0, cascade_delete => 0 },
);

=head2 devices

Type: has_many

Related object: L<Conch::Legacy::Schema::Result::Device>

=cut

__PACKAGE__->has_many(
  "devices",
  "Conch::Legacy::Schema::Result::Device",
  { "foreign.hardware_product" => "self.id" },
  { cascade_copy               => 0, cascade_delete => 0 },
);

=head2 hardware_product_profile

Type: might_have

Related object: L<Conch::Legacy::Schema::Result::HardwareProductProfile>

=cut

__PACKAGE__->might_have(
  "hardware_product_profile",
  "Conch::Legacy::Schema::Result::HardwareProductProfile",
  { "foreign.product_id" => "self.id" },
  { cascade_copy         => 0, cascade_delete => 0 },
);

=head2 vendor

Type: belongs_to

Related object: L<Conch::Legacy::Schema::Result::HardwareVendor>

=cut

__PACKAGE__->belongs_to(
  "vendor",
  "Conch::Legacy::Schema::Result::HardwareVendor",
  { id            => "vendor" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

# Created by DBIx::Class::Schema::Loader v0.07047 @ 2018-01-12 11:35:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZLHVx+uuGswuhZ4u7QxssQ

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
