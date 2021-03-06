# Conch::DB::Result::DeviceLocation

## SOURCE

[https://github.com/joyent/conch-api/blob/master/lib/Conch/DB/Result/DeviceLocation.pm](https://github.com/joyent/conch-api/blob/master/lib/Conch/DB/Result/DeviceLocation.pm)

## BASE CLASS: [Conch::DB::Result](../modules/Conch%3A%3ADB%3A%3AResult)

## TABLE: `device_location`

## ACCESSORS

### rack\_id

```
data_type: 'uuid'
is_foreign_key: 1
is_nullable: 0
size: 16
```

### rack\_unit\_start

```
data_type: 'integer'
is_foreign_key: 1
is_nullable: 0
```

### created

```
data_type: 'timestamp with time zone'
default_value: current_timestamp
is_nullable: 0
original: {default_value => \"now()"}
```

### updated

```
data_type: 'timestamp with time zone'
default_value: current_timestamp
is_nullable: 0
original: {default_value => \"now()"}
```

### device\_id

```
data_type: 'uuid'
is_foreign_key: 1
is_nullable: 0
size: 16
```

## PRIMARY KEY

- ["device\_id"](#device_id)

## UNIQUE CONSTRAINTS

### `device_location_rack_id_rack_unit_start_key`

- ["rack\_id"](#rack_id)
- ["rack\_unit\_start"](#rack_unit_start)

## RELATIONS

### device

Type: belongs\_to

Related object: [Conch::DB::Result::Device](../modules/Conch%3A%3ADB%3A%3AResult%3A%3ADevice)

### rack

Type: belongs\_to

Related object: [Conch::DB::Result::Rack](../modules/Conch%3A%3ADB%3A%3AResult%3A%3ARack)

### rack\_layout

Type: belongs\_to

Related object: [Conch::DB::Result::RackLayout](../modules/Conch%3A%3ADB%3A%3AResult%3A%3ARackLayout)

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
