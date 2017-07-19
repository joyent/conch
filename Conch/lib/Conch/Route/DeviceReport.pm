package Conch::Route::DeviceReport;

use Dancer2 appname => 'Conch';
use Hash::MultiValue;
use Dancer2::Plugin::LogReport;
use Dancer2::Plugin::DBIC;
use Conch::Data::DeviceReport;
use Log::Report::DBIC::Profiler;
set serializer => 'JSON';


prefix '/api' => sub {

  post '/device' => sub {
    # dr: device_report
    my $dr;

    eval {
      $dr = Conch::Data::DeviceReport->new(body_parameters->as_hashref);
    };
    if ($@) {
      my $errs = join("\n\t- ", map { $_->message } $@->errors);
      error "Error validating device report:\n\t- $errs";
    };

    schema->storage->debugobj(new Log::Report::DBIC::Profiler);
    schema->storage->debug(1);

    my $hw = resultset('HardwareProduct')->find({
      name => $dr->{product_name}
    });
    $hw or error "Product $dr->{product_name} not found";

    my $hw_profile = $hw->hardware_product_profile;
    $hw or fault "Hardware product $hw->{name} exists but does not have a hardware profile";

    success "Ready to record report for Device $dr->{serial_number}";

    try { schema->txn_do (sub {
        my $device_rs = resultset('Device')->update_or_create({
          id               => $dr->{serial_number},
          system_uuid      => $dr->{system_uuid},
          hardware_product => $hw->id,
          state            => $dr->{state},
          health           => "UNKNOWN",
          last_seen        => \'NOW()',
        });
        my $device_id = $device_rs->id;
        success "Created Device $device_id";

        my %interfaces = %{$dr->{interfaces}};
        my $nics_num = keys %interfaces;

        my $device_specs = resultset('DeviceSpec')->update_or_create({
          device_id       => $device_id,
          product_id      => $hw_profile->id,
          bios_firmware   => $dr->{bios_version},
          cpu_num         => $dr->{processor}->{count},
          cpu_type        => $dr->{processor}->{type},
          nics_num        => $nics_num,
          dimms_num       => $dr->{memory}->{count},
          ram_total       => $dr->{memory}->{total},
        });

        success "Created Device Spec for Device $device_id";

        my $device_env = resultset('DeviceEnvironment')->update_or_create({
            device_id       => $device_rs->id,
            cpu0_temp       => $dr->{temp}->{cpu0},
            cpu1_temp       => $dr->{temp}->{cpu1},
            inlet_temp      => $dr->{temp}->{inlet},
            exhaust_temp    => $dr->{temp}->{exhaust},
          });

        success "Recorded environment for Device $device_id";

        # XXX If a disk vanishes/replaces, we need to mark it deactivated here.
        foreach my $disk (keys %{$dr->{disks}}) {
          trace "Device $device_id: Recording disk: $disk";

          my $disk_rs = resultset('DeviceDisk')->update_or_create({
            device_id       => $device_rs->id,
            serial_number   => $disk,
            slot            => $dr->{disks}->{$disk}->{slot},
            hba             => $dr->{disks}->{$disk}->{hba},
            vendor          => $dr->{disks}->{$disk}->{vendor},
            health          => $dr->{disks}->{$disk}->{health},
            size            => $dr->{disks}->{$disk}->{size},
            model           => $dr->{disks}->{$disk}->{model},
            temp            => $dr->{disks}->{$disk}->{temp},
            drive_type      => $dr->{disks}->{$disk}->{drive_type},
            transport       => $dr->{disks}->{$disk}->{transport},
            firmware        => $dr->{disks}->{$disk}->{firmware},
          });
        }

        success "Recorded disk info for Device $device_id";

        foreach my $nic (keys %{$dr->{interfaces}}) {

          trace "Device $device_id: Recording NIC: $dr->{interfaces}->{$nic}->{mac}";

          my $nic_rs = resultset('DeviceNic')->update_or_create({
              mac           => $dr->{interfaces}->{$nic}->{mac},
              device_id     => $device_rs->id,
              iface_name    => $nic,
              iface_type    => $dr->{interfaces}->{$nic}->{product},
              iface_vendor  => $dr->{interfaces}->{$nic}->{vendor},
              iface_driver  => "",
            });

          my $nic_state = resultset('DeviceNicState')->update_or_create({
              mac           => $dr->{interfaces}->{$nic}->{mac},
              state         => $dr->{interfaces}->{$nic}->{state},
              ipaddr        => $dr->{interfaces}->{$nic}->{ipaddr},
              mtu           => $dr->{interfaces}->{$nic}->{mtu},
            });

          my $nic_peers = resultset('DeviceNeighbor')->update_or_create({
              mac           => $dr->{interfaces}->{$nic}->{mac},
              raw_text      => $dr->{interfaces}->{$nic}->{peer_text},
              peer_switch   => $dr->{interfaces}->{$nic}->{peer_switch},
              peer_port     => $dr->{interfaces}->{$nic}->{peer_port},
            });
        }
      });
    };
    if ($@) { $@->reportFatal; }

    return {status => "success"};
  };

};

1;
