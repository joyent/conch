=head1 NAME

Conch::Orc::Workflow::Status

=head1 DESCRIPTION

Represents the overall status of a particular Workflow

=cut

package Conch::Orc::Workflow::Status;

use strict;
use warnings;
use utf8;
use v5.20;

use Moo;
use experimental qw(signatures);

use Try::Tiny;
use Type::Tiny;
use Types::Standard qw(Num ArrayRef Bool Str Enum InstanceOf);
use Types::UUID qw(Uuid);

use Conch::Pg;
use Conch::Orc;

=head1 CONSTANTS

	$status->status( Conch::Orc::Workflow::Status->ONGOING );

The following constants are available and link directly to values in the
C<e_workflow_status> enum in the database.


=over 4

=item ABORT

=item COMPLETED

=item ONGOING

=item RESUME

=item STOPPED

=back

=cut

use constant {
	ABORT     => 'abort',
	COMPLETED => 'completed',
	ONGOING   => 'ongoing',
	RESUME    => 'resume',
	STOPPED   => 'stopped',
};


=head1 ACCESSORS

=over 4

=item id

UUID. Cannot be written by user.

=cut

has 'id' => (
	is  => 'rwp',
	isa => Uuid,
);


=item workflow_id

UUID. Required. FK'd into C<workflow(id)>

=cut

has 'workflow_id' => (
	is       => 'rw',
	required => 1,
	isa      => Uuid,
);


=item workflow

A C<Conch::Orc::Workflow> object, lazy loaded using C<workflow_id>

=cut

has 'workflow' => (
	clearer => 1,
	is      => 'lazy',
	builder => sub {
		my $self = shift;
		return Conch::Orc::Workflow->from_id($self->workflow_id);
	},
);



=item device_id

UUID. Required. FK'd into C<device(id)>

=cut

has 'device_id' => (
	is       => 'rw',
	required => 1,
	isa      => Str,
);


=item device

A C<Conch::Model::Device> object, lazy loaded using C<device_id>

=cut

has 'device' => (
	clearer => 1,
	is      => 'lazy',
	builder => sub {
		my $self = shift;
		return Conch::Model::Device->lookup($self->device_id);
	},
);


=item timestamp

Conch::Time. Defaults to C<<< Conch::Time->now >>>. Represents the time this
status update occurred

=cut

has 'timestamp' => (
	is      => 'rw',
	isa     => InstanceOf["Conch::Time"],
	default => sub { Conch::Time->now() },
);


=item status

One of the constants listed above. Defaults to ONGOING

=cut

has 'status' => (
	is      => 'rw',
	isa     => Enum[ ABORT, COMPLETED, ONGOING, RESUME, STOPPED ],
	default => ONGOING,
);

=back

=head1 METHODS

=head2 from_id

Load a Status from its UUID

=cut

sub from_id ($class, $uuid) {
	my $ret;
	try {
		$ret = Conch::Pg->new()->db->select('workflow_status', undef, { 
			id => $uuid
		})->hash;
	} catch {
		Mojo::Exception->throw(__PACKAGE__."->from_id: $_");
		return undef;
	};

	return $class->new(
		device_id   => $ret->{device_id},
		id          => $ret->{id},
		status      => $ret->{status},
		timestamp   => Conch::Time->new($ret->{timestamp}),
		workflow_id => $ret->{workflow_id},
	);
}


=head2 many_from_latest_status

	my $many = Conch::Orc::Workflow::Status->many_from_latest_status(
		Conch::Orc::Workflow::Status->ONGOING
	);

Returns an arrayref containing Status objects. These status objects represent
the most recent update for their given workflow, if the status matches the
provided value.

This can be used, for instance, to find all workflows that are ONGOING.

=cut

sub many_from_latest_status ($class, $status) {
	my $ret;
	try {
		$ret = Conch::Pg->new()->db->select('orc_latest_workflow_status',
			undef,
			{ status => $status }
		)->hashes;
	} catch {
		Mojo::Exception->throw(__PACKAGE__."->many_from_latest_status: $_");
		return undef;
	};

	unless (scalar $ret->@*) {
		return [];
	}

	my @many = map {
		my $s = $_;
		$s->{timestamp} = Conch::Time->new($s->{timestamp});
		$class->new($s);
	} $ret->@*;

	return \@many;
}


=head2 many_from_device

	my $device = Conch::Model::Device->from_id('wat');
	my $many = Conch::Orc::Workflow::Status->many_from_device($device);

Returns an arrayref containing all the Status objects for a given Device,
sorted by timestamp.

=cut

sub many_from_device($class, $d) {
	my $ret;
	try {
		$ret = Conch::Pg->new()->db->select('workflow_status', undef, { 
			device_id => $d->id
		})->hashes;
	} catch {
		Mojo::Exception->throw(__PACKAGE__."->many_from_device: $_");
		return undef;
	};

	unless (scalar $ret->@*) {
		return [];
	}

	my @many = sort {
		$b->timestamp cmp $a->timestamp
	} map {
		my $s = $_;
		$s->{timestamp} = Conch::Time->new($s->{timestamp});
		$class->new($s);
	} $ret->@*;

	return \@many;
}



=head2 latest_from_device

	my $device = Conch::Model::Device->from_id('wat');
	my $many = Conch::Orc::Workflow::Status->latest_from_device($device);

Returns a single Status object, representing the most recent Status for a given
device.

=cut

sub latest_from_device($class, $d) {
	my $ret;
	try {
		$ret = Conch::Pg->new()->db->query(qq|
			select * from workflow_status where device_id = ?
				order by timestamp asc
				limit 1
		|, $d->id)->hash;
	} catch {
		Mojo::Exception->throw(__PACKAGE__."->latest_from_device: $_");
		return undef;
	};

	return undef unless $ret;

	$ret->{timestamp} = Conch::Time->new($ret->{timestamp});
	return $class->new($ret->%*);
}


=head2 many_from_execution

	my $ex = Conch::Orc::Workflow::Exception->new($device_id, $workflow_id);
	my $many = Conch::Orc::Workflow::Status->many_from_execution($ex):

Returns an arrayref containing all the Status objects for a given
Workflow::Execution, sorted by timestamp

=cut

sub many_from_execution($class, $ex) {
	my $ret;
	try {
		$ret = Conch::Pg->new()->db->select('workflow_status', undef, { 
			device_id   => $ex->device_id,
			workflow_id => $ex->workflow_id,
		})->hashes;
	} catch {
		Mojo::Exception->throw(__PACKAGE__."->many_from_execution: $_");
		return undef;
	};

	unless (scalar $ret->@*) {
		return [];
	}

	my @many = sort {
		$a->timestamp cmp $b->timestamp
	} map {
		my $s = $_;
		$s->{timestamp} = Conch::Time->new($s->{timestamp});
		$class->new($s);
	} $ret->@*;

	return \@many;
}


=head2 latest_from_execution

	my $ex = Conch::Orc::Workflow::Exception->new($device_id, $workflow_id);
	my $many = Conch::Orc::Workflow::Status->latest_from_execution($ex):

Returns the latest Status for a given workflow

=cut

sub latest_from_execution ($class, $ex) {
	# XXX This should really be a database query so we don't have to pull back
	# and process every single status for that execution.
	return $class->many_from_execution($ex)->[-1];
}


=head2 save

Saves or updates the Status

=cut

sub save ($self) {
	my $db = Conch::Pg->new()->db;

	my $tx = $db->begin;
	my $ret;
	my %fields = (
		device_id   => $self->device_id,
		status      => $self->status,
		timestamp   => $self->timestamp->timestamptz,
		workflow_id => $self->workflow_id,
	);
	try {
		if($self->id) {
			$ret = $db->update(
				'workflow_status',
				\%fields,
				{ id => $self->id }, 
				{ returning => [qw(id timestamp)]}
			)->hash;
		} else {
			$ret = $db->insert(
				'workflow_status',
				\%fields,
				{ returning => [qw(id timestamp)] }
			)->hash;
		}
	} catch {
		Mojo::Exception->throw(__PACKAGE__."->save: $_");
		return undef;
	};
	$tx->commit;

	$self->_set_id($ret->{id});
	$self->timestamp(Conch::Time->new($ret->{timestamp}));

	return $self;

}


=head2 v1

Returns a hashref, representing the Status in v1 format

=cut

sub v1 ($self) {
	{
		device_id   => $self->device_id,
		id          => $self->id,
		status      => $self->status,
		timestamp   => $self->timestamp->to_string,
		workflow_id => $self->workflow_id,
	}
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

