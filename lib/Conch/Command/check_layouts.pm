package Conch::Command::check_layouts;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Getopt::Long::Descriptive;

=pod

=head1 NAME

check_layouts - check for rack layout conflicts

=head1 SYNOPSIS

    check_layouts [long options...]

        --help  print usage message and exit

=cut

has description => 'Check for occupancy conflicts in existing rack layouts';

has usage => sub { shift->extract_usage };  # extracts from SYNOPSIS

sub run ($self) {

    local @ARGV = @_;
    my ($opt, $usage) = describe_options(
        # the descriptions aren't actually used anymore (mojo uses the synopsis instead)... but
        # the 'usage' text block can be accessed with $usage->text
        'check_layouts %o',
        [],
        [ 'help',           'print usage message and exit', { shortcircuit => 1 } ],
    );

    my $workspace_rs = $self->app->db_workspaces;
    while (my $workspace = $workspace_rs->next) {
        my $rack_rs = $workspace->self_rs->associated_racks;

        while (my $rack = $rack_rs->next) {
            my %occupied;
            ++$occupied{$_} foreach $rack->self_rs->occupied_rack_units;

            foreach my $rack_unit (sort { $a <=> $b } keys %occupied) {
                if ($occupied{$rack_unit} > 1) {
                    print '# for workspace ', $workspace->id, ' (', $workspace->name,
                        '), datacenter_rack_id ', $rack->id, ' (', $rack->name, '), found ',
                        "$occupied{$rack_unit} occupants at rack_unit $rack_unit!\n";
                }
            }
        }
    }
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
