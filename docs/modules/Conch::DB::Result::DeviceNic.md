# Conch::DB::Result::DeviceNic

## SOURCE

[https://github.com/joyent/conch/blob/master/lib/Conch/DB/Result/DeviceNic.pm](https://github.com/joyent/conch/blob/master/lib/Conch/DB/Result/DeviceNic.pm)

## BASE CLASS: [Conch::DB::Result](../modules/Conch%3A%3ADB%3A%3AResult)

## TABLE: `device_nic`

## ACCESSORS

### mac

```
data_type: 'macaddr'
is_nullable: 0
```

### iface\_name

```
data_type: 'text'
is_nullable: 0
```

### iface\_type

```
data_type: 'text'
is_nullable: 0
```

### iface\_vendor

```
data_type: 'text'
is_nullable: 0
```

### deactivated

```
data_type: 'timestamp with time zone'
is_nullable: 1
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

### state

```
data_type: 'text'
is_nullable: 1
```

### ipaddr

```
data_type: 'inet'
is_nullable: 1
```

### mtu

```
data_type: 'integer'
is_nullable: 1
```

### device\_id

```
data_type: 'uuid'
is_foreign_key: 1
is_nullable: 0
size: 16
```

## PRIMARY KEY

- ["mac"](#mac)

## RELATIONS

### device

Type: belongs\_to

Related object: [Conch::DB::Result::Device](../modules/Conch%3A%3ADB%3A%3AResult%3A%3ADevice)

### device\_neighbor

Type: might\_have

Related object: [Conch::DB::Result::DeviceNeighbor](../modules/Conch%3A%3ADB%3A%3AResult%3A%3ADeviceNeighbor)

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
