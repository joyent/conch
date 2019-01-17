package Conch::Validation::SataHddNum;

use Mojo::Base 'Conch::Validation';
use v5.20;

has 'name'        => 'sata_hdd_num';
has 'version'     => 1;
has 'category'    => 'DISK';
has 'description' => q( Validate expected number of SATA HDDs );

sub validate {
	my ( $self, $data ) = @_;

	$self->die("Input data must include 'disks' hash")
		unless $data->{disks} && ref( $data->{disks} ) eq 'HASH';

	my $hw_profile = $self->hardware_product_profile;

	my $sata_hdd_count =
		grep { $_->{drive_type} && fc( $_->{drive_type} ) eq fc('SATA_HDD') }
		( values $data->{disks}->%* );

	$self->register_result(
		expected => $hw_profile->sata_hdd_num || 0,
		got      => $sata_hdd_count,
	);

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
