use utf8;
package Conch::DB::Result::DatacenterRack;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Conch::DB::Result::DatacenterRack

=cut

use strict;
use warnings;


=head1 BASE CLASS: L<Conch::DB::Result>

=cut

use base 'Conch::DB::Result';

=head1 TABLE: C<datacenter_rack>

=cut

__PACKAGE__->table("datacenter_rack");

=head1 ACCESSORS

=head2 id

  data_type: 'uuid'
  default_value: gen_random_uuid()
  is_nullable: 0
  size: 16

=head2 datacenter_room_id

  data_type: 'uuid'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 datacenter_rack_role_id

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

=head2 serial_number

  data_type: 'text'
  is_nullable: 1

=head2 asset_tag

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "uuid",
    default_value => \"gen_random_uuid()",
    is_nullable => 0,
    size => 16,
  },
  "datacenter_room_id",
  { data_type => "uuid", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "datacenter_rack_role_id",
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
  "serial_number",
  { data_type => "text", is_nullable => 1 },
  "asset_tag",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 datacenter_rack_layouts

Type: has_many

Related object: L<Conch::DB::Result::DatacenterRackLayout>

=cut

__PACKAGE__->has_many(
  "datacenter_rack_layouts",
  "Conch::DB::Result::DatacenterRackLayout",
  { "foreign.rack_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 datacenter_rack_role

Type: belongs_to

Related object: L<Conch::DB::Result::DatacenterRackRole>

=cut

__PACKAGE__->belongs_to(
  "datacenter_rack_role",
  "Conch::DB::Result::DatacenterRackRole",
  { id => "datacenter_rack_role_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 datacenter_room

Type: belongs_to

Related object: L<Conch::DB::Result::DatacenterRoom>

=cut

__PACKAGE__->belongs_to(
  "datacenter_room",
  "Conch::DB::Result::DatacenterRoom",
  { id => "datacenter_room_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 device_locations

Type: has_many

Related object: L<Conch::DB::Result::DeviceLocation>

=cut

__PACKAGE__->has_many(
  "device_locations",
  "Conch::DB::Result::DeviceLocation",
  { "foreign.rack_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 workspace_datacenter_racks

Type: has_many

Related object: L<Conch::DB::Result::WorkspaceDatacenterRack>

=cut

__PACKAGE__->has_many(
  "workspace_datacenter_racks",
  "Conch::DB::Result::WorkspaceDatacenterRack",
  { "foreign.datacenter_rack_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 workspaces

Type: many_to_many

Composing rels: L</workspace_datacenter_racks> -> workspace

=cut

__PACKAGE__->many_to_many("workspaces", "workspace_datacenter_racks", "workspace");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-09-28 09:38:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:e7KR0yeDiZbe2VZiOALn7g

__PACKAGE__->add_columns(
    '+deactivated' => { is_serializable => 0 },
);

sub TO_JSON {
    my $self = shift;

    my $data = $self->next::method(@_);
    $data->{role} = delete $data->{datacenter_rack_role_id};
    return $data;
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
