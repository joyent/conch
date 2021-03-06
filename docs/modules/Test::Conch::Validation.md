# Test::Conch::Validation - Test Conch Validations

## SOURCE

[https://github.com/joyent/conch-api/blob/master/lib/Test/Conch/Validation.pm](https://github.com/joyent/conch-api/blob/master/lib/Test/Conch/Validation.pm)

## EXPORTABLE FUNCTIONS

### test\_validation

A function to test a Conch Validation using a collection of provided test cases.

This function performs the following tests:

- Test whether the validation builds.
- Tests whether the validations defines the required `name`, `version`,
and `description` attributes.

The required arguments are the Conch Validation module as a string, keyword
arguments specifying data to be made available to the Validation, and a keyword
argument specifying the cases for the test to use.

The only data made directly available to the validation is `device`, so (most) data
should be nested underneath that, following the database schema.
For example:

```
test_validation(
    'Conch::Validation::TestValidation',
    device => {
        asset_tag => 'foo',
        hardware_product => {
            name => 'Product Name',
            vendor => 'Product Vendor',
            cpu_num => 2,
        },
        device_location => {
            rack_unit_start => 2,
        },
        device_settings => {
            foo => 'bar'
        },
    },
    rack_layouts => [
        { rack_unit_start => 1 },
        { rack_unit_start => 2 },
        { rack_unit_start => 3 },
    ],

    cases => [ ... ]
);
```

`cases` is a list of hashrefs defining each of the test cases. Each case
specifies the input data and attributes representing the expected results. Each
test case may raise an error (die) or may produce 0 or more validation results.
A test case is specified with a hashref with the attributes:

- `data`

    A hashref of the input data provide to the Validation. An empty hashref will be provided by default.

- `success_num`

    The number of expected successful validation results from running the
    Validation with the provided `data`. Defaults to 0.

- `failure_num`

    The number of expected failing validation results from running the Validation
    with the provided `data`. Defaults to 0

- `error_num`

    The number of expected 'error' validation results from running the Validation
    with the provided `data`. Defaults to 0.

- `description`

    Optional description of the test case. Provides documentation and adds the
    description to test failure messages.

- `debug`

    Optional boolean flag to provide additional diagnostic information when running
    the case using ["diag" in Test::More](https://metacpan.org/pod/Test%3A%3AMore#diag). This is helpful during development of test
    cases, but should be removed before committing.

Example:

```
test_validation(
    'Conch::Validation::TestValidation',
    cases => [
        {
            data        => { hello => 'world' },
            success_num => 3,
            failure_num => 3,
            description => 'Hello world test case',
            debug       => 1
        }
    ]
);
```

## LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [https://www.mozilla.org/en-US/MPL/2.0/](https://www.mozilla.org/en-US/MPL/2.0/).
