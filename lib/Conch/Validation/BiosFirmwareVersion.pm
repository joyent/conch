package Conch::Validation::BiosFirmwareVersion;
use Mojo::Base -base;
use Role::Tiny::With;
with("Conch::Role::Validation");

use constant {
	'name'        => 'bios_firmware_version',
	'version'     => 1,
	'category'    => 'BIOS',
	'description' => "Validate the reported BIOS firmware version matches the hardware product profile"
};

sub validate {
	my ( $self, $data ) = @_;

	$self->die("Missing 'bios_version'") unless $data->{bios_version};

	my $hw_profile = $self->hardware_product->profile;

	$self->register_result(
		expected => $hw_profile->bios_firmware,
		got      => $data->{bios_version}
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
