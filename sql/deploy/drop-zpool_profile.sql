BEGIN;

    alter table hardware_product_profile drop column zpool_id;
    drop table zpool_profile;

COMMIT;
