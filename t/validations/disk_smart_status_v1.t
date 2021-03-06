use v5.20;
use warnings;
use Test::More;
use Test::Warnings;
use Test::Conch::Validation 'test_validation';

test_validation(
    'Conch::Validation::DiskSmartStatus',
    device => {
        hardware_product => {
            name => 'Test Product',
        },
    },
    cases => [
        {
            description => 'No Data yields no success',
            data        => {},
        },
        {
            description => 'No disks yields no success',
            data        => {
                disks => {}
            },
        },
        {
            description => 'Disk with OK SMART',
            data        => {
                disks => {
                    DEADBEEF => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "OK",
                        transport  => "sas",
                    },
                }
            },
            success_num => 1
        },
        {
            description => 'Multiple disks with OK SMART have multiple results',
            data        => {
                disks => {
                    DEADBEEF => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "OK",
                        transport  => "sas",
                    },
                    COFFEE => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "OK",
                        transport  => "sas",
                    },
                }
            },
            success_num => 2
        },
        {
            description => 'USB disk not checked',
            data        => {
                disks => {
                    DEADBEEF => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "OK",
                        transport  => "sas",
                    },
                    COFFEE => {
                        transport => "usb",
                    },
                }
            },
            success_num => 1
        },
        {
            description => 'RAID LUN not checked',
            data        => {
                disks => {
                    DEADBEEF => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "OK",
                        transport  => "sas",
                    },
                    COFFEE => {
                        device     => "sdb",
                        drive_type => "RAID_LUN",
                    },
                }
            },
            success_num => 1
        },
        {
            description => 'Disk without SMART health attribute',
            data        => {
                disks => {
                    DEADBEEF => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        transport  => "sas",
                    },
                }
            },
            failure_num => 1
        },
        {
            description => 'Disk non-OK SMART',
            data        => {
                disks => {
                    DEADBEEF => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "FAIL",
                        transport  => "sas",
                    },
                }
            },
            failure_num => 1
        },
        {
            description => 'Multiple disks with non-OK SMART',
            data        => {
                disks => {
                    DEADBEEF => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "FAIL",
                        transport  => "sas",
                    },
                    COFFEE => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "FAIL",
                        transport  => "sas",
                    },
                }
            },
            failure_num => 2
        },
        {
            description => 'Disks with both OK and non-OK SMART',
            data        => {
                disks => {
                    DEADBEEF => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "OK",
                        transport  => "sas",
                    },
                    COFFEE => {
                        device     => "sda",
                        drive_type => "SAS_SSD",
                        health     => "FAIL",
                        transport  => "sas",
                    },
                }
            },
            success_num => 1,
            failure_num => 1
        },
    ]
);

done_testing;
