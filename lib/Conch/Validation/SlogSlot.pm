package Conch::Validation::SlogSlot;

use Mojo::Base 'Conch::Validation';
use v5.20;

use constant name        => 'slog_slot';
use constant version     => 1;
use constant category    => 'DISK';
use constant description => 'Validate ZFS SLOG is in slot 0';

sub validate {
    my ($self, $data) = @_;

    $self->die("Input data must include 'disks' hash")
        unless $data->{disks} && ref($data->{disks}) eq 'HASH';

    my @disks_with_drive_type =
        grep { $_->{drive_type} } (values $data->{disks}->%*);

    my @ssd_disks = grep {
        fc($_->{drive_type}) eq fc('SAS_SSD')
            || fc($_->{drive_type}) eq fc('SATA_SSD')
    } @disks_with_drive_type;

    # Ensure slog is in slot 0 on mixed media systems
    if (scalar(@ssd_disks) == 1) {
        my $slog_slot = $ssd_disks[0]->{slot};

        $self->register_result(
            expected => 0,
            got      => $slog_slot,
            hint     => 'ZFS SLOG is in wrong slot'
        );
    }
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
