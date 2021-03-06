package Conch::Validation::RaidLunNum;

use Mojo::Base 'Conch::Validation';
use v5.20;

use constant name        => 'raid_lun_num';
use constant version     => 1;
use constant category    => 'DISK';
use constant description => 'Validate expected number of RAID LUNs';

sub validate {
    my ($self, $data) = @_;

    $self->die("Input data must include 'disks' hash")
        unless $data->{disks} && ref($data->{disks}) eq 'HASH';

    my $raid_lun_count =
        grep { $_->{drive_type} && fc($_->{drive_type}) eq fc('RAID_LUN') }
        (values $data->{disks}->%*);

    $self->register_result(
        expected => $self->hardware_product->raid_lun_num,
        got      => $raid_lun_count,
    );
}

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<https://www.mozilla.org/en-US/MPL/2.0/>.

=cut
