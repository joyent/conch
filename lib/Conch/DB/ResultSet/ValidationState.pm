package Conch::DB::ResultSet::ValidationState;
use v5.26;
use warnings;
use parent 'Conch::DB::ResultSet';

use experimental 'signatures';

=head1 NAME

Conch::DB::ResultSet::ValidationState

=head1 DESCRIPTION

Interface to queries involving validation states.

=head1 METHODS

=head2 with_results

Generates a resultset that adds the validation_results to the validation_state(s) in the
resultset.

=cut

sub with_results ($self) {
    $self
        ->prefetch({ validation_state_members => 'validation_result' })
        ->order_by('validation_state_members.result_order');
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
# vim: set ts=4 sts=4 sw=4 et :
