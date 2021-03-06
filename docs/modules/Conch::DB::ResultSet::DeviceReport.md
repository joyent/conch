# Conch::DB::ResultSet::DeviceReport

## SOURCE

[https://github.com/joyent/conch-api/blob/master/lib/Conch/DB/ResultSet/DeviceReport.pm](https://github.com/joyent/conch-api/blob/master/lib/Conch/DB/ResultSet/DeviceReport.pm)

## DESCRIPTION

Interface to queries involving device reports.

## METHODS

### with\_report\_status

Given a resultset indicating one or more report(s), adds a column to the result indicating
the cumulative status of all the validation state record(s) associated with it (that is, if all
pass, then return 'pass', otherwise consider if any were 'error' or 'fail').

Reports with no validation results are considered to be a 'pass'.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
