package Conch::Control::Device::Network;

use strict;
use Log::Report;
use List::Util 'first';
use JSON::XS;

use Data::Printer;

use Exporter 'import';
our @EXPORT = qw( validate_links validate_wiremap );

sub validate_links {
  my ($schema, $device, $report_id) = @_;

  my $device_id = $device->id;
  trace("$device_id: report $report_id: Validating network links");

  my $device_nics = $device->device_nics;

  my $links_up;
  while ( my $iface = $device_nics->next ) {
    next if $iface->iface_name eq "ipmi1";
    my $nic_state = $iface->device_nic_state;

    # XXX Once we have a wiremap, we should go off the wiremap, and this naive
    # check.  We expect to have 4 links up.
    $links_up++ if $nic_state->state eq "up";
  }

  trace("$device_id: report $report_id: validating links_up");
  my $nic_state_msg;
  my $nic_state_status;

  my $nic_state_log = "Has = $links_up, Want = 4";
  if ( $links_up < 4 ) {
    $nic_state_msg = "$device_id: report $report_id: CRITICAL: links_up: $nic_state_log";
    mistake $nic_state_msg;
    $nic_state_status = 0;
   } else {
     $nic_state_msg = "$device_id: report $report_id: OK: links_up: $nic_state_log";
     trace $nic_state_msg;
     $nic_state_status = 1;
   }

   $schema->resultset('DeviceValidate')->create({
     device_id       => $device_id,
     report_id       => $report_id,
     validation      => encode_json({
       component_type  => "NET",
       component_name  => "links_up",
       log             => $nic_state_msg,
       status          => $nic_state_status,
     })
   });
}

sub validate_wiremap {
  my ($schema, $device, $report_id) = @_;

  my $device_id = $device->id;
  trace("$device_id: report $report_id: Validating network links");

  my @device_nics = $device->device_nics->all;

  trace("$device_id: Validating network switch peers");

  my @eth_nics = grep {$_->iface_name =~ /eth/} @device_nics;
  my $rack_location = $device->device_location;

  if (! $rack_location) {
    error "$device_id is not assigned in a rack; cannot validate wiremap";
    return 0;
  }

  my @rack_layout = $schema->resultset('DatacenterRackLayout')->search(
    { rack_id => $rack_location->rack_id },
    { order_by => { -asc => ['ru_start'] } }
  )->all;
  my @rack_slots = map { $_->ru_start } @rack_layout;

  my @peer_ports = switch_peer_ports($rack_location->rack_unit, @rack_slots);
  my $switch_peers = {};

  for my $nic (@eth_nics) {
    my $nic_neighbor = $nic->device_neighbor;
    my $peer_port    = $nic_neighbor->peer_port;
    my $peer_name    = $nic_neighbor->peer_mac;

    # skip if the link doesn't have a peer configured
    next unless $peer_port;

    $switch_peers->{$peer_name}->{$peer_port} = 1;

    my $nic_peer_log;
    my $nic_peer_status;
    my $nic_peer_msg = "Interface ".$nic->iface_name." Has $peer_port, Needs either of @peer_ports";
    if (grep /\Q$peer_port/, @peer_ports) {
      $nic_peer_log = "$device_id: report $report_id: OK: Correct peer: $nic_peer_msg";
      $nic_peer_status = 1;
      info $nic_peer_log;
    }
    else {
      $nic_peer_log ="$device_id: report $report_id: CRITICAL: Wrong peer port: $nic_peer_msg";
      $nic_peer_status = 0;
      mistake $nic_peer_log;
    }

    $schema->resultset('DeviceValidate')->create({
      device_id       => $device_id,
      report_id       => $report_id,
      validation      => encode_json({
          component_type  => "NET",
          component_name  => $nic->mac . "_peer",
          log             => $nic_peer_msg,
          status          => $nic_peer_status
        })
    });
  }

  # Validate the number of switches
  my $num_switches = keys %{$switch_peers};

  my $num_switch_log;
  my $num_switch_status;
  my $num_switch_msg = "Has $num_switches peer switch(es), Needs 2";
  if ($num_switches == 2) {
    $num_switch_log = "$device_id: report $report_id: OK: Correct number of switches: $num_switch_msg";
    $num_switch_status = 1;
    info $num_switch_log;
  }
  else {
    $num_switch_log = "$device_id: report $report_id: CRITICAL: Wrong number of switches: $num_switch_msg";
    $num_switch_status = 0;
    mistake $num_switch_log;
  }

  $schema->resultset('DeviceValidate')->create({
      device_id       => $device_id,
      report_id       => $report_id,
      validation      => encode_json({
          component_type  => "NET",
          component_name  => "num_switch_peers",
          log             => $num_switch_msg,
          status          => $num_switch_status
        })
    });

  # Validate the number of ports per switch
  # Since $switch_peer is a hashref, duplicates will be detected as only having
  # 1 port
  for my $switch_name (keys %{$switch_peers}) {
    my $num_ports = keys %{$switch_peers->{$switch_name}};
    my $num_ports_log;
    my $num_ports_status;
    my $num_ports_msg = "Has $num_ports port(s) connected to switch $switch_name, Needs 2";
    if ($num_ports == 2) {
      $num_ports_log = "$device_id: report $report_id: OK: Correct number of peer ports: $num_ports_msg";
      $num_ports_status = 1;
      info $num_ports_log;
    }
    else {
      $num_ports_log = "$device_id: report $report_id: CRITICAL: Wrong number of peer ports: $num_ports_msg";
      $num_ports_status = 0;
      mistake $num_ports_log;
    }

    $schema->resultset('DeviceValidate')->create({
        device_id       => $device_id,
        report_id       => $report_id,
        validation      => encode_json({
            component_type  => "NET",
            component_name  => "num_peer_switch_ports",
            log             => $num_ports_msg,
            status          => $num_ports_status
          })
      });
  }

}

sub switch_peer_ports {
  my ($rack_unit, @rack_slots) = @_;
  my $rack_index = first { $rack_slots[$_] == $rack_unit } 0..$#rack_slots;
  defined $rack_index or error 'Device assigned to rack unit not in rack layout';

  my $first_port = 1 + $rack_index;
  # offset of 19 is standard for all deployments, including 62U racks
  my $second_port = $first_port + 19;

  return ("1/$first_port", "1/$second_port");
}


1;
