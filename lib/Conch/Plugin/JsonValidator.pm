package Conch::Plugin::JsonValidator;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use JSON::Validator;

use constant OUTPUT_SCHEMA_FILE => "json-schema/response.yaml";
use constant INPUT_SCHEMA_FILE => "json-schema/input.yaml";

=pod

=head1 NAME

Conch::Plugin::JsonValidator

=head1 SYNOPSIS

    app->plugin('Conch::Plugin::JsonValidator');

    [ ... in a controller ]

    sub endpoint ($c) {
        my $body = $c->validate_input("MyInputDefinition");

        [ ... ]

        $c->status_with_validation(200, MyOutputDefinition => $ret);
    }

=head1 DESCRIPTION

Conch::Plugin::JsonValidator provides an optional manner to validate input and
output from a Mojo controller against JSON Schema.

The C<validate_input> helper uses the provided schema definition to validate
B<JUST> the incoming JSON request. Headers and query parameters B<ARE NOT>
validated. If the data fails validation, a 400 status is returned to user
with an error payload containing the validation errors.

The C<status_with_validation> helper validates the outgoing data against the
provided schema definition. If the data validates, C<status> is called, using
the provided status code and data. If the data validation fails, a
C<Mojo::Exception> is thrown, returning a 500 to the user.

=head1 SCHEMAS

C<validate_input> validates data against the C<json-schema/input.yaml> file.

=head1 METHODS

=head2 register

Load the plugin into Mojo. Called by Mojo directly

=cut

sub register ($self, $app, $config) {

    my $validator = JSON::Validator->new();
    $validator->schema(INPUT_SCHEMA_FILE);

    $app->helper(validate_input => sub ($c, $schema_name_or_definition, $json = $c->req->json) {
        my $schema =
            ref $schema_name_or_definition ? $schema_name_or_definition
          : $validator->get("/definitions/$schema_name_or_definition");

        if (not $schema) {
            Mojo::Exception->throw("unable to locate schema $schema");
            return;
        }

        if (my @errors = $validator->validate($json, $schema)) {
            $c->log->error("FAILED data validation for schema $schema_name_or_definition: ".join(' // ', @errors));
            return $c->status(400 => { error => join("\n",@errors) });
        }

        $c->log->debug("Passed data validation for input schema $schema_name_or_definition");
        return $json;
    });
}

1;
__END__

=pod

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

=cut
# vim: set ts=4 sts=4 sw=4 et :
