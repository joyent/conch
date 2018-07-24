package Conch::Command::create_user;

=pod

=head1 NAME

create_user - create a new user, optionally sending an email

=head1 SYNOPSIS

   bin/conch create_user --email <email> --name <name> [--password <password>] [--send-mail]

  --email       The user's email address. Required.
  --name        The user's name. Required.
  --password    The user's temporary password. If not provided, one will be randomly generated.
  --send-mail   When set, a welcome message will be mailed to the user.

=cut

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long::Descriptive;
use Conch::Mail;

has description => 'Create a new user';

has usage => sub { shift->extract_usage };  # extracts from SYNOPSIS

sub run {
    my $self = shift;

    local @ARGV = @_;
    my ($opt, $usage) = describe_options(
        'create_user %o',
        [ 'name|n=s',       'the user\'s name', { required => 1 } ],
        [ 'email|e=s',      'the user\'s email address', { required => 1 } ],
        [ 'password|p=s',   'the user password', { default => _random_password() } ],
        [ 'send-email',     'send email to user' ],
        [],
        [ 'help',           'print usage message and exit', { shortcircuit => 1 } ],
    );

    my $rs = $self->app->schema->resultset('UserAccount');

    if ($rs->search([ name => $opt->name, email => $opt->email ])->count) {
        $self->app->log->warn('cannot create user: name ' . $opt->name . ' and/or email ' . $opt->email . ' already exists');
        return;
    }

    my $user = $rs->new_result({
        name => $opt->name,
        email => $opt->email,
        password => $opt->password, # will be hashed in constructor
    });

    $user->insert;
    my $user_id = $user->id;

    say 'created user ', $opt->name, ' with email ', $opt->email, ': user id ', $user_id;

    if ($opt->send_email) {
        say 'sending email to ', $opt->email, '...';
        Conch::Mail::new_user_invite({ email => $opt->email, password => $opt->password });
    }
}

sub _random_password {
    my @chars = ('A'..'Z', 'a'..'z', 0..9);
    my $string = '';
    $string .= $chars[rand @chars] for 1..8;
    return $string;
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