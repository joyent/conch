## Conch::Log

Enhanced Mojo logger with formatters to log in
[Bunyan](https://github.com/trentm/node-bunyan) format, optionally with stack traces.

## SYNOPSIS

```perl
$app->log(Conch::Log->new(bunyan => 1));

$app->log->debug('a message');

local $Conch::Log::REQUEST_ID = 'deadbeef';
$log->info({ raw_data => [1,2,3] });
```

## ATTRIBUTES

[Conch::Log](../modules/Conch%3A%3ALog) inherits all attributes from [Mojo::Log](https://metacpan.org/pod/Mojo%3A%3ALog) and implements the
following new ones:

### bunyan

A boolean option (defaulting to false): log in bunyan format. If passed a string or list of
strings, these are added as the `msg` field in the logged data; otherwise, the passed-in data
will be included as-is.

`$Conch::Log::REQUEST_ID` is included in the data, when defined (make sure to localize this to
the scope of your request or asynchronous subroutine).

### with\_trace

A boolean option (defaulting to false): include stack trace information. Must be combined with
`bunyan => 1`.

## METHODS

[Conch::Log](../modules/Conch%3A%3ALog) inherits all methods from [Mojo::Log](https://metacpan.org/pod/Mojo%3A%3ALog).

### format

Automatically selects the format subroutine based on configuration values.

## SEE ALSO

[node-bunyan](https://github.com/trentm/node-bunyan/)

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
