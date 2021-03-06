# Conch::Route::RackLayout

## SOURCE

[https://github.com/joyent/conch-api/blob/master/lib/Conch/Route/RackLayout.pm](https://github.com/joyent/conch-api/blob/master/lib/Conch/Route/RackLayout.pm)

## METHODS

### routes

Sets up the routes for /layout.

### one\_layout\_routes

Sets up the routes for working with just one layout, mounted under a provided route prefix.

## ROUTE ENDPOINTS

All routes require authentication.

Take note: All routes that reference a specific rack layout (prefix `/layout/:layout_id`) are
also available under `/rack/:rack_id_or_long_name/layout/:layout_id_or_rack_unit_start` as
well as
`/room/datacenter_room_id_or_alias/rack/:rack_id_or_name/layout/:layout_id_or_rack_unit_start`.

### `GET /layout`

- Requires system admin authorization
- Controller/Action: ["get\_all" in Conch::Controller::RackLayout](../modules/Conch%3A%3AController%3A%3ARackLayout#get_all)
- Response: [response.json#/$defs/RackLayouts](../json-schema/response.json#/$defs/RackLayouts)

### `POST /layout`

- Requires system admin authorization
- Controller/Action: ["create" in Conch::Controller::RackLayout](../modules/Conch%3A%3AController%3A%3ARackLayout#create)
- Request: [request.json#/$defs/RackLayoutCreate](../json-schema/request.json#/$defs/RackLayoutCreate)
- Response: `201 Created`, plus Location header

### `GET /layout/:layout_id`

- Requires system admin authorization
- Controller/Action: ["get" in Conch::Controller::RackLayout](../modules/Conch%3A%3AController%3A%3ARackLayout#get)
- Response: [response.json#/$defs/RackLayout](../json-schema/response.json#/$defs/RackLayout)

### `POST /layout/:layout_id`

- Requires system admin authorization
- Controller/Action: ["update" in Conch::Controller::RackLayout](../modules/Conch%3A%3AController%3A%3ARackLayout#update)
- Request: [request.json#/$defs/RackLayoutUpdate](../json-schema/request.json#/$defs/RackLayoutUpdate)
- Response: `204 No Content`, plus Location header

### `DELETE /layout/:layout_id`

- Requires system admin authorization
- Controller/Action: ["delete" in Conch::Controller::RackLayout](../modules/Conch%3A%3AController%3A%3ARackLayout#delete)
- Response: `204 No Content`

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
