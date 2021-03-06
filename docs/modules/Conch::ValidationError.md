# Conch::ValidationError - Internal error representation for Conch::Validation

## SOURCE

[https://github.com/joyent/conch-api/blob/master/lib/Conch/ValidationError.pm](https://github.com/joyent/conch-api/blob/master/lib/Conch/ValidationError.pm)

## DESCRIPTION

Extends [Mojo::Exception](https://metacpan.org/pod/Mojo%3A%3AException) to store a `hint` attribute. Intended for use in
[Conch::Validation](../modules/Conch%3A%3AValidation).

## METHODS

### error\_loc

Return a description of where the error occurred. Provides the module name and
line number, but not the filepath, so it doesn't expose where the file lives.

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
