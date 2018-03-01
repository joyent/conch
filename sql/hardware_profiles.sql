INSERT INTO hardware_product_profile ( product_id, purpose, bios_firmware, cpu_num, cpu_type, 
            dimms_num, ram_total, nics_num, psu_total, rack_unit )
       VALUES ( ( SELECT id FROM hardware_product WHERE name = 'S4048-ON' ),
            'TOR switch', '9.11(2.5)', 1, 'Intel Rangeley',
            1, 3, 48, 2, 1
       );

INSERT INTO hardware_product_profile ( product_id, purpose, bios_firmware, cpu_num, cpu_type,
            dimms_num, ram_total, nics_num, sas_num, sas_size, ssd_num, ssd_size, ssd_slots, psu_total, zpool_id,
            rack_unit )
       VALUES (  ( SELECT id FROM hardware_product WHERE name = 'Joyent-Storage-Platform-7001' ),
            'Manta Object Store', 'American Megatrends Inc. 2.0a', 2, 'Intel(R) Xeon(R) CPU E5-2690 v4 @ 2.60GHz',
            16, 512, 7, 35, 7452.04, 1, 93.16, '0', 2,
            ( SELECT id FROM zpool_profile WHERE name = 'Joyent-Storage-Platform-7001' ),
            4
       );

INSERT INTO hardware_product_profile ( product_id, purpose, bios_firmware, cpu_num, cpu_type,
            dimms_num, ram_total, nics_num, sas_num, sas_size, ssd_num, ssd_size, ssd_slots, psu_total, zpool_id,
            rack_unit )
       VALUES (  ( SELECT id FROM hardware_product WHERE name = 'Joyent-Storage-Platform-7201' ),
            'Mass Storage', 'American Megatrends Inc. 2.0a', 2, 'Intel(R) Xeon(R) CPU E5-2690 v4 @ 2.60GHz',
            16, 512, 7, 35, 7452.04, 1, 93.16, '0', 2,
            ( SELECT id FROM zpool_profile WHERE name = 'Joyent-Storage-Platform-7201' ),
            4
        );

INSERT INTO hardware_product_profile ( product_id, purpose, bios_firmware, cpu_num, cpu_type,
            dimms_num, ram_total, nics_num, sas_num, sas_size, ssd_num, ssd_size, ssd_slots, psu_total, zpool_id,
            rack_unit )
      VALUES (  ( SELECT id FROM hardware_product WHERE name = 'Joyent-Compute-Platform-3301' ),
            'General Compute', 'Dell Inc. 2.2.5', 2, 'Intel(R) Xeon(R) CPU E5-2690 v4 @ 2.60GHz',
            16, 256, 7, 15, 1117.81, 1, 93.16, '0', 2,
            ( SELECT id FROM zpool_profile WHERE name = 'Joyent-Compute-Platform-3301' ),
            2
       );

INSERT INTO hardware_product_profile ( product_id, purpose, bios_firmware, cpu_num, cpu_type,
            dimms_num, ram_total, nics_num, sas_num, sas_size, ssd_num, ssd_size, ssd_slots, psu_total, zpool_id,
            rack_unit )
      VALUES (  ( SELECT id FROM hardware_product WHERE name = 'Joyent-Compute-Platform-3101' ),
            'General Compute', '2.0a', 2, 'Intel(R) Xeon(R) CPU E5-2690 v4 @ 2.60GHz',
            16, 512, 7, 15, 1117.81, 1, 93.16, '0', 2,
            ( SELECT id FROM zpool_profile WHERE name = 'Joyent-Compute-Platform-3101' ),
            2
       );

INSERT INTO hardware_product_profile ( product_id, purpose, bios_firmware, cpu_num, cpu_type,
            dimms_num, ram_total, nics_num, sas_num, ssd_num, ssd_size, ssd_slots, psu_total, zpool_id,
            rack_unit )
      VALUES (  ( SELECT id FROM hardware_product WHERE name = 'Joyent-Compute-Platform-3302' ),
            'SSD Compute', 'Dell Inc. 2.2.5', 2, 'Intel(R) Xeon(R) CPU E5-2690 v4 @ 2.60GHz',
            16, 256, 7, 0, 16, 1490.42, '0-15', 2,
            ( SELECT id FROM zpool_profile WHERE name = 'Joyent-Compute-Platform-3302' AND disk_per = 16 ),
            2
       );

INSERT INTO hardware_product_profile ( product_id, purpose, bios_firmware, cpu_num, cpu_type,
            dimms_num, ram_total, nics_num, sas_num, sas_size, ssd_num, ssd_size, ssd_slots, psu_total,
            rack_unit )
      VALUES (  ( SELECT id FROM hardware_product WHERE name = 'CERES' ),
            'CPG Compute', 'Dell Inc. 2.2.5', 2, 'Intel(R) Xeon(R) CPU E5-2690 v4 @ 2.60GHz',
            16, 256, 7, 15, 1117.81, 1, 93.16, '0', 2,
            2
       );
