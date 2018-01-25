package Conch::Model::Relay;
use Mojo::Base -base, -signatures;

use Try::Tiny;

has 'pg';

sub create ( $self, $serial, $version, $ipaddr, $ssh_port, $alias,
	$ip_origin = undef )
{
	my $ret;
	try {
		$ret = $self->pg->db->query(
			q{
      INSERT INTO relay
        ( id, version, ipaddr, ssh_port, updated )
      VALUES
        ( ?, ?, ?, ?, ? )
      ON CONFLICT (id) DO UPDATE
      SET id = excluded.id,
          version = excluded.version,
          ipaddr = excluded.ipaddr,
          ssh_port = excluded.ssh_port,
          updated = excluded.updated
    },
			$serial,
			$version,
			$ipaddr,
			$ssh_port,
			'NOW()'
		)->rows;
	};
	return $ret;
}

sub lookup ( $self, $relay_id ) {
	return $self->pg->db->select( 'relay', undef, { id => $relay_id } )->hash;
}

# Associate relay with a user
sub connect_user_relay ( $self, $user_id, $relay_id ) {
	my $ret;
	try {
		# 'first_seen' column will only be written on create. It should remain
		# unchanged on updates
		$ret = $self->pg->db->query(
			q{
        INSERT INTO user_relay_connection
          ( user_id, relay_id, last_seen )
        VALUES
          ( ?, ?, ? )
        ON CONFLICT (user_id, relay_id) DO UPDATE
        SET user_id = excluded.user_id,
            relay_id = excluded.relay_id,
            last_seen = excluded.last_seen
      }, $user_id, $relay_id, 'NOW()'
		)->rows;
	};
	return $ret;
}

# Associate relay with a device
sub connect_device_relay ( $self, $device_id, $relay_id ) {
	my $ret;
	try {
		# 'first_seen' column will only be written on create. It should remain
		# unchanged on updates
		$ret = $self->pg->db->query(
			q{
        INSERT INTO device_relay_connection
          ( device_id, relay_id, last_seen )
        VALUES
          ( ?, ?, ? )
        ON CONFLICT (device_id, relay_id) DO UPDATE
        SET device_id = excluded.device_id,
            relay_id = excluded.relay_id,
            last_seen = excluded.last_seen
      }, $device_id, $relay_id, 'NOW()'
		)->rows;
	};
	return $ret;
}

1;
