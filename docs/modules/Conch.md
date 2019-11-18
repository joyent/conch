# NAME

Conch - Setup and helpers for Conch Mojo app

# SYNOPSIS

```
Mojolicious::Commands->start_app('Conch');
```

# METHODS

## startup

Used by Mojo in the startup process. Loads the config file and sets up the
helpers, routes and everything else.

## startup\_time

Stores a [Conch::Time](/modules/Conch%3A%3ATime) instance representing the time the server started accepting requests.

# LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).
