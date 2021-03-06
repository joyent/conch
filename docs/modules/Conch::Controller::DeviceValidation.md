# Conch::Controller::DeviceValidation

## SOURCE

[https://github.com/joyent/conch-api/blob/master/lib/Conch/Controller/DeviceValidation.pm](https://github.com/joyent/conch-api/blob/master/lib/Conch/Controller/DeviceValidation.pm)

## METHODS

### get\_validation\_state

Get the latest validation state for a device. Accepts the query parameter `status`,
indicating the desired status(es) to limit the search -- one or more of: pass, fail, error.
e.g. `?status=pass`, `?status=error&status=fail`. (If no parameters are provided, all
statuses are searched for.)

Response uses the ValidationStateWithResults json schema.

### validate

Validate the device against the specified validation.

**DOES NOT STORE VALIDATION RESULTS**.

This is useful for testing and evaluating experimental validations against a given device.

Response uses the LegacyValidationResults json schema.

### run\_validation\_plan

Validate the device against the specified Validation Plan.

**DOES NOT STORE VALIDATION RESULTS**.

This is useful for testing and evaluating Validation Plans against a given
device.

Response uses the LegacyValidationResults json schema.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
