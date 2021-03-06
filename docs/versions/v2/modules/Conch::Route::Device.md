# NAME

Conch::Route::Device

# METHODS

## routes

Sets up the routes for /device:

Unless otherwise noted, all routes require authentication.

### `POST /device/:device_id`

- Request: device\_report.yaml
- Response: response.yaml#/ValidationStateWithResults

### `GET /device?:key=:value`

Supports the following query parameters:

- `/device?hostname=:hostname`
- `/device?mac=:macaddr`
- `/device?ipaddr=:ipaddr`
- `/device?:setting_key=:setting_value`

The value of `:setting_key` and `:setting_value` are a device setting key and
value. For information on how to create a setting key or set its value see
below.

- Response: response.yaml#/Devices

### `GET /device/:device_id`

- Response: response.yaml#/DetailedDevice

### `GET /device/:device_id/pxe`

- Response: response.yaml#/DevicePXE

### `GET /device/:device_id/phase`

- Response: response.yaml#/DevicePhase

### `POST /device/:device_id/graduate`

- Request: input.yaml#/Null
- Response: Redirect to the updated device

### `POST /device/:device_id/triton_setup`

- Request: input.yaml#/Null
- Response: Redirect to the updated device

### `POST /device/:device_id/triton_uuid`

- Request: input.yaml#/DeviceTritonUuid
- Response: Redirect to the updated device

### `POST /device/:device_id/triton_reboot`

- Request: input.yaml#/Null
- Response: Redirect to the updated device

### `POST /device/:device_id/asset_tag`

- Request: input.yaml#/DeviceAssetTag
- Response: Redirect to the updated device

### `POST /device/:device_id/validated`

- Request: input.yaml#/Null
- Response: Redirect to the updated device

### `POST /device/:device_id/phase`

- Request: input.yaml#/DevicePhase
- Response: Redirect to the updated device

### `GET /device/:device_id/location`

- Response: response.yaml#/DeviceLocation

### `POST /device/:device_id/location`

- Request: input.yaml#/DeviceLocationUpdate
- Response: Redirect to the updated device

### `DELETE /device/:device_id/location`

- Response: `204 NO CONTENT`

### `GET /device/:device_id/settings`

- Response: response.yaml#/DeviceSettings

### `POST /device/:device_id/settings`

- Requires Read/Write Device Authentication
- Request: input.yaml#/DeviceSettings
- Response: `204 NO CONTENT`

### `GET /device/:device_id/settings/:key`

- Response: response.yaml#/DeviceSetting

### `POST /device/:device_id/settings/:key`

- Requires Read/Write Device Authentication
- Request: input.yaml#/DeviceSettings
- Response: `204 NO CONTENT`

### `DELETE /device/:device_id/settings/:key`

- Requires Read/Write Device Authentication
- Response: `204 NO CONTENT`

### `POST /device/:device_id/validation/:validation_id`

Does not store validation results.

- Request: device\_report.yaml
- Response: response.yaml#/ValidationResults

### `POST /device/:device_id/validation_plan/:validation_plan_id`

Does not store validation results.

- Request: device\_report.yaml
- Response: response.yaml#/ValidationResults

### `GET /device/:device_id/validation_state?status=<pass,fail,error>`

Accepts the query parameter `status`, indicating the desired status(es)
(comma-separated) to search for -- one or more of: `pass`, `fail`, `error`.

- Response: response.yaml#/ValidationStatesWithResults

### `GET /device/:device_id/interface`

- Response: response.yaml#/DeviceNics

### `GET /device/:device_id/interface/:interface_name`

- Response: response.yaml#/DeviceNic

### `GET /device/:device_id/interface/:interface_name/:field`

- Response: response.yaml#/DeviceNicField

# LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).
