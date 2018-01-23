
INSERT INTO zpool_profile (name, vdev_t, vdev_n, disk_per, spare, log, cache)
       VALUES ( 'Joyent-Compute-Platform-3301', 'mirror', 7, 2, 1, 1, 0 );

INSERT INTO zpool_profile (name, vdev_t, vdev_n, disk_per, spare, log, cache)
       VALUES ( 'Joyent-Storage-Platform-7001', 'raidz2', 3, 11, 2, 1, 0 );

UPDATE hardware_product_profile
    SET zpool_id =
        ( SELECT id FROM zpool_profile WHERE name = 'Joyent-Compute-Platform-3301' )
    WHERE product_id =
        ( SELECT id FROM hardware_product WHERE name = 'Joyent-Compute-Platform-3301' );

UPDATE hardware_product_profile
    SET zpool_id =
        ( SELECT id FROM zpool_profile WHERE name = 'Joyent-Storage-Platform-7001' )
    WHERE product_id =
        ( SELECT id FROM hardware_product WHERE name = 'Joyent-Storage-Platform-7001' );

