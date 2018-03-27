use Test::More;
use Test::Conch::Validation;

test_validation(
	'Conch::Validation::DiskTemperature',
	hardware_product => {
		name => 'Test Product',
	},
	cases => [
		{
			description => 'No Data',
			data        => {},
			dies        => 1
		},
		{
			description => 'No disks',
			data        => {
				disks => {}
			},
			dies => 1,
		},
		{
			description => 'Disk without temp',
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
			description => 'Disk with temp under threshold',
			data        => {
				disks => {
					DEADBEEF => {
						device     => "sda",
						drive_type => "SAS_SSD",
						transport  => "sas",
						temp       => 20
					},
				}
			},
			success_num => 1
		},
		{
			description => 'Multiple disks with temps under threshold',
			data        => {
				disks => {
					DEADBEEF => {
						device     => "sda",
						drive_type => "SAS_SSD",
						transport  => "sas",
						temp       => 20
					},
					COFFEE => {
						device     => "sda",
						drive_type => "SAS_HDD",
						transport  => "sas",
						temp       => 52
					},
				}
			},
			success_num => 2
		},
		{
			description => 'Disk with temp over threshold (51)',
			data        => {
				disks => {
					DEADBEEF => {
						device     => "sda",
						drive_type => "SAS_SSD",
						transport  => "sas",
						temp       => 52
					},
				}
			},
			failure_num => 1
		},
		{
			description => 'Multiple disks with temp over threshold',
			data        => {
				disks => {
					DEADBEEF => {
						device     => "sda",
						drive_type => "SAS_SSD",
						transport  => "sas",
						temp       => 52
					},
					COFFEE => {
						device     => "sda",
						drive_type => "SAS_HDD",
						transport  => "sas",
						temp       => 61
					},
				}
			},
			failure_num => 2
		},
		{
			description => 'Disks with temps both over and under threshold',
			data        => {
				disks => {
					DEADBEEF => {
						device     => "sda",
						drive_type => "SAS_SSD",
						transport  => "sas",
						temp       => 50
					},
					COFFEE => {
						device     => "sda",
						drive_type => "SAS_HDD",
						transport  => "sas",
						temp       => 61
					},
				}
			},
			success_num => 1,
			failure_num => 1
		},
	]
);

done_testing();
