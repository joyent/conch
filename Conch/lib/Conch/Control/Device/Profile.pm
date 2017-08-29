package Conch::Control::Device::Profile;

use v5.10;
use strict;
use experimental 'smartmatch';

use List::Compare;
use Log::Report;
use Log::Report::DBIC::Profiler;
use Dancer2::Plugin::Passphrase;

use Data::Printer;

use Exporter 'import';
our @EXPORT =
  qw( determine_product set_device_settings set_device_setting
      get_device_settings get_device_setting );


sub set_device_settings {
  my ($schema, $device, $settings) = @_;

  my @hardware_settings =
    $device
    ->hardware_product
    ->hardware_product_profile
    ->hardware_profile_settings
    ->all;

  my $resource_ids = {};
  for my $hardware_setting (@hardware_settings) {
    $resource_ids->{$hardware_setting->name} = $hardware_setting->id;
  }

  $schema->txn_do (sub {

    for my $setting_key (keys %{$settings}) {
      # may be 'undef'
      my $resource_id = $resource_ids->{$setting_key};
      my $value = $settings->{$setting_key};

      my $prev_setting =
        $device->device_settings
        ->find({resource_id => $resource_id, deactivated => undef});
      $prev_setting->update({ deactivated => \'NOW()' }) if $prev_setting;
      $device->device_settings->create({
          device_id   => $device->id,
          resource_id => $resource_id,
          name        => $setting_key,
          value       => $value
      });
    }

  });

  return 1;
}

sub set_device_setting {
  my ($schema, $device, $setting_key, $setting_value) = @_;

  my $hardware_setting =
    $device
    ->hardware_product
    ->hardware_product_profile
    ->hardware_profile_settings
    ->find({name => $setting_key});

  $schema->txn_do (sub {

      my $prev_setting =
        $device->device_settings
        ->find({name => $setting_key, deactivated => undef});
      $prev_setting->update({ deactivated => \'NOW()' })
        if $prev_setting;
      $device->device_settings->create({
          device_id   => $device->id,
          resource_id => $hardware_setting ? $hardware_setting->id : undef,
          name        => $setting_key,
          value       => $setting_value
      });
  });

  return 1;
}

sub get_device_settings {

  my ($schema, $device) = @_;

  my @device_settings = $device->device_settings->search({
        deactivated => undef
      })->all;

  my $res = {};
  for my $setting (@device_settings) {
    $res->{$setting->name} = $setting->value;
  }
  return $res;
}

sub get_device_setting {
  my ($schema, $device, $setting_key) = @_;

  return $device->device_settings->find({
      name        => $setting_key,
      deactivated => undef
    });
}

# XXX We should use 'hardware_product_profile' to determine the these details
sub determine_product {
  my ($schema, $serial, $profile) = @_;

  my $product = {};

  # Determine vendor
  if ($profile->{vendor} =~ /dell/i) {
    $product->{vendor} = "dell";
  }
  elsif ($profile->{vendor} =~ /supermicro/i) {
    $product->{vendor} = "smci";
  }
  else {
    if (length($serial) == 7) {
      $product->{vendor} = "dell";
    }
    elsif (length($serial) == 7) {
      $product->{vendor} = "smci";
    }
    else {
      warning "Unable to determine product vendor";
      $product->{vendor} = "UNKNOWN";
    }
  }

  for($product->{vendor}) {

    when(/dell/) {
      for($profile->{disk_count}) {
        if ($_ == 12) {
          $product->{model} = "type1-ceres";
        }
        elsif ($_ == 15) {
          $product->{model} = "jcp-3301";
        }
        elsif ($_ == 8 || $_ == 16) {
          $product->{model} = "jcp-3302";
        }

        # Possible disk failures, fallback
        else {
          if ($profile->{mb_string} eq "072T6D") {
             $product->{model} = "hallasan";
          }
          else {
            warning "Unable to determine Dell model";
            $product->{model} = "UNKNOWN";
          }
       }
      }
    }

    when(/smci/) {
      if ($profile->{disk_count} == 35) {
        $product->{model} = "jsp-7001";
      }

      # Possible disk failures, fallback
      else {
        if ($profile->{mb_string} eq "X10DRH-iT") {
          $product->{model} = "jsp-7001";
        }
        else {
            warning "Unable to determine SMCI model";
            $product->{model} = "UNKNOWN";
        }
      }
    }

    default {
      warning "Unable to determine model for vendor $product->{vendor}";
      $product->{model} = "UNKNOWN";
    }
  }

  return $product;
}


1;
