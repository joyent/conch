INSERT INTO datacenter_rack_role ( name, rack_size ) VALUES ( 'TEST_RACK_ROLE', 10 );

INSERT INTO datacenter (vendor, vendor_name, region, location )
    VALUES ( 'Test Vendor', 'Test Name', 'test-region-1', 'Testlandia, Testopolis');

INSERT INTO datacenter_room (datacenter, az, alias, vendor_name)
    VALUES ( ( SELECT id FROM datacenter WHERE region = 'test-region-1' ), 'test-region-1a', 'TT1', 'TEST1.1');

INSERT INTO datacenter_rack (datacenter_room_id, name, role)
    VALUES (
        ( SELECT id FROM datacenter_room WHERE az = 'test-region-1a' ),
        'Test Rack',
        ( SELECT id FROM datacenter_rack_role WHERE name =  'TEST_RACK_ROLE' )
    );

INSERT INTO datacenter_rack_layout (rack_id, product_id, ru_start)
    VALUES (
        ( SELECT id FROM datacenter_rack WHERE name = 'Test Rack' ),
        ( SELECT id FROM hardware_product WHERE name = 'Joyent-Compute-Platform-3301'),
        1
    );

INSERT INTO datacenter_rack_layout (rack_id, product_id, ru_start)
    VALUES (
        ( SELECT id FROM datacenter_rack WHERE name = 'Test Rack' ),
        ( SELECT id FROM hardware_product WHERE name = 'Joyent-Compute-Platform-3301'),
        3
    );
