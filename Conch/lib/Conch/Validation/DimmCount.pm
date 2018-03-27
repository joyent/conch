package Conch::Validation::DimmCount;

use Mojo::Base 'Conch::Validation';

has 'name'        => 'dimm_count';
has 'version'     => 1;
has 'description' => 'Verify the number of DIMMs reported';

has schema => sub {
	{
		required => ['memory'],
		memory => {
			type       => 'object',
			properties => {
				required => ['count'],
				count => { type => 'integer' }
			}
		}
	};
};

sub validate {
	my ( $self, $data ) = @_;

	my $hw_profile = $self->hardware_product_profile;

	my $dimms_num  = $data->{memory}->{count};
	my $dimms_want = $hw_profile->dimms_num;

	# Shrimps can have 256GB or 512GB RAM, with 8 or 16 DIMMs.
	if ( $self->hardware_product_name eq 'Joyent-Storage-Platform-7001' ) {
		if ( $dimms_num <= 8 ) { $dimms_want = 8; }
		if ( $dimms_num > 8 )  { $dimms_want = 16; }
	}

	$self->register_result(
		expected       => $dimms_want,
		got            => $dimms_num,
		component_type => 'RAM'
	);
}

1;

__DATA__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut
