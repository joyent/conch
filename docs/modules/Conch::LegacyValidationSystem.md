# Conch::LegacyValidationSystem

## SOURCE

[https://github.com/joyent/conch-api/blob/master/lib/Conch/LegacyValidationSystem.pm](https://github.com/joyent/conch-api/blob/master/lib/Conch/LegacyValidationSystem.pm)

## METHODS

### check\_validation\_plans

Verifies that all validations mentioned in validation plans correspond to modules we actually
have available in Conch::Validation::\*.

Legacy Validations not referenced by an active plan are ignored.

Returns a tuple, indicating the number of valid and invalid plans checked.

### check\_validation\_plan

Verifies that a validation plan and its validations are all correct (correct
parent class, module attributes match database fields, etc).

Returns the name of all modules successfully loaded.

### load\_validations

Load all Conch::Validation::\* sub-classes into the database.
Existing validation records will not be modified if attributes change -- instead, existing
records will be deactivated and new records will be created to reflect the updated data.

Returns a tuple: the number of validations that were deactivated, and the number of new
validation rows that were created.

This method is poorly-named: it should be 'create\_validations'.

### update\_validation\_plans

Deactivate and/or create validation records for all validation modules currently present, then
updates validation plan membership to reference the newest versions of the validations it
previously had as members.

That is: does whatever is necessary after a code deployment to ensure that validation plans
continue to run validations pointing to the same code modules.

### run\_validation\_plan

Runs the provided validation\_plan against the provided device and device report.

All provided data objects can and should be read-only (fetched with a ro db handle).

If `no_save_db => 1` is passed, the validation records are returned (along with the
overall result status), without writing them to the database. Otherwise, a validation\_state
record is created and legacy\_validation\_result records saved with deduplication logic applied.

Takes options as a hash:

```perl
validation_plan => $plan,       # required, a Conch::DB::Result::LegacyValidationPlan object
device => $device,              # required, a Conch::DB::Result::Device object
device_report => $report,       # optional, a Conch::DB::Result::DeviceReport object
                                # (required if no_save_db is false)
data => $data,                  # optional, a hashref of device report data; required if
                                # device_report is not provided
no_save_db => 0|1               # optional, defaults to false
```

### run\_validation

Runs the provided validation record against the provided device and device report.
Creates and returns legacy\_validation\_result records, without writing them to the database.

All provided data objects can and should be read-only (fetched with a ro db handle).

Takes options as a hash:

```perl
validation => $validation,      # required, a Conch::DB::Result::LegacyValidation object
device => $device,              # required, a Conch::DB::Result::Device object
data => $data,                  # required, a hashref of device report data
```

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
