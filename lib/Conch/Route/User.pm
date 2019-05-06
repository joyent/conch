package Conch::Route::User;

use Mojo::Base -strict, -signatures;

=pod

=head1 NAME

Conch::Route::User

=head1 METHODS

=head2 routes

Sets up the routes for /user:

=cut

sub routes {
    my $class = shift;
    my $user = shift;    # secured, under /user

    # all these routes go to the User controller
    $user->to({ controller => 'user' });

    # interfaces for user updating their own account...
    {
        # all /user/me routes operate with the target user set to ourselves
        my $user_me = $user->under('/me')
            ->to(cb => sub ($c) { $c->stash('target_user', $c->stash('user')); return 1 });

        # GET /user/me
        $user_me->get('/')->to('#get');

        # POST /user/me/revoke?send_mail=<1|0>& login_only=<0|1> or ?api_only=<0|1>
        $user_me->post('/revoke')->to('#revoke_user_tokens');

        # POST /user/me/password?clear_tokens=<login_only|0|all>
        # (after changing password, (possibly) pass through to logging out too)
        $user->under('/me/password')->to('#change_own_password')
            ->post('/')->to('login#session_logout');

        {
            my $user_me_settings = $user_me->any('/settings');

            # GET /user/me/settings
            $user_me_settings->get('/')->to('#get_settings');
            # POST /user/me/settings
            $user_me_settings->post('/')->to('#set_settings');

            # 'key' is extracted into the stash
            my $user_me_settings_with_key = $user_me_settings->any('/#key');

            # GET /user/me/settings/#key
            $user_me_settings_with_key->get('/')->to('#get_setting');
            # POST /user/me/settings/#key
            $user_me_settings_with_key->post('/')->to('#set_setting');
            # DELETE /user/me/settings/#key
            $user_me_settings_with_key->delete('/')->to('#delete_setting');
        }

        {
            my $user_me_token = $user_me->any('/token');

            # GET /user/me/token
            $user_me_token->get('/')->to('#get_api_tokens');
            # POST /user/me/token
            $user_me_token->post('/')->to('#create_api_token');

            # note: because we use a wildcard placeholder for token_name, nothing else
            # can be added to the route after the name.
            my $with_token = $user_me_token->under('/*token_name')->to('#find_api_token');

            # GET /user/me/token/*token_name
            $with_token->get('/')->to('#get_api_token');

            # DELETE /user/me/token/*token_name
            $with_token->delete('/')->to('#expire_api_token');
        }
    }

    # administrator interfaces for updating a different user's account...
    {
        # syntax: <uuid> or email=<email address>
        my $user_with_target = $user->require_system_admin->under('/#target_user_id_or_email')
            ->to(cb => sub ($c) { $c->find_user($c->stash('target_user_id_or_email')) });

        # GET /user/#target_user_id_or_email
        $user_with_target->get('/')->to('#get');
        # POST /user/#target_user_id_or_email?send_mail=<1|0>
        $user_with_target->post('/')->to('#update');
        # DELETE /user/#target_user_id_or_email?clear_tokens=<1|0>
        $user_with_target->delete('/')->to('#deactivate');

        # POST /user/#target_user_id_or_email/revoke?login_only=<0|1> or ?api_only=<0|1>
        $user_with_target->post('/revoke')->to('#revoke_user_tokens');
        # DELETE /user/#target_user_id_or_email/password?clear_tokens=<login_only|0|all>&send_password_reset_mail=<1|0>
        $user_with_target->delete('/password')->to('#reset_user_password');

        # GET /user
        $user->require_system_admin->get('/')->to('#list');
        # POST /user?send_mail=<1|0>
        $user->require_system_admin->post('/')->to('#create');

        {
            my $user_with_target_token = $user_with_target->any('/token');

            # GET /user/#target_user_id_or_email/token
            $user_with_target_token->get('/')->to('#get_api_tokens');

            # note: because we use a wildcard placeholder for token_name, nothing else
            # can be added to the route after the name.
            my $with_token = $user_with_target_token->under('/*token_name')->to('#find_api_token');

            # GET /user/#target_user_id_or_email/token/*token_name
            $with_token->get('/')->to('#get_api_token');

            # DELETE /user/#target_user_id_or_email/token/*token_name
            $with_token->delete('/')->to('#expire_api_token');
        }
    }
}

1;
__END__

=pod

Unless otherwise noted, all routes require authentication.

=head3 C<GET /user/me>

=over 4

=item * Response: response.yaml#/UserDetailed

=back

=head3 C<< POST /user/me/revoke?send_mail=<1|0>& login_only=<0|1> or ?api_only=<0|1> >>

Optionally accepts the following query parameters:

=over 4

=item * C<< send_mail=<1|0> >> (default 1) - send an email telling the user their tokens were revoked

=item * C<< login_only=<0|1> >> (default 0) - revoke only login/session tokens

=item * C<< api_only=<0|1> >> (default 0) - revoke only  API tokens

=back

By default it will revoke both login/session and API tokens. If both
C<api_only> and C<login_only> are set, no tokens will be revoked.

=over 4

=item * Request: input.yaml#/UserSettings

=item * Response: C<204 NO CONTENT>

=back

=head3 C<< POST /user/me/password?clear_tokens=<login_only|0|all> >>

Optionally takes a query parameter C<clear_tokens>, to also revoke the session
tokens for the user, forcing the user to log in again. Possible options are:

=over 4

=item * C<0>, C<no>, C<false>

=item * C<login_only>, C<1> (default, for backcompat, C<1> is treated as C<login_only>)

=item * C<all> - also affects all API tokens (and thus other tools).

=back

If the C<clear_tokens> parameter is set to C<0>, C<no>, C<false> then
C<204 NO CONTENT> will be returned but the user session will remain..

=over 4

=item * Request: input.yaml#/UserSettings

=item * Response: C<204 NO CONTENT> (The user session is terminated).

=back


=head3 C<GET /user/me/settings>

=over 4

=item * Response: response.yaml#/UserSettings

=back

=head3 C<POST /user/me/settings>

=over 4

=item * Request: input.yaml#/UserSettings

=item * Response: C<204 NO CONTENT>

=back

=head3 C<GET /user/me/settings/:key>

=over 4

=item * Response: response.yaml#/UserSetting

=back

=head3 C<POST /user/me/settings/:key>

=over 4

=item * Request: input.yaml#/UserSetting

=item * Response: C<204 NO CONTENT>

=back

=head3 C<DELETE /user/me/settings/:key>

=over 4

=item * Request: input.yaml#/DeviceSetting

=item * Response: C<204 NO CONTENT>

=back

=head3 C<GET /user/me/token>

=over 4

=item * Response: response.yaml#/UserTokens

=back

=head3 C<POST /user/me/token>

=over 4

=item * Response: input.yaml#/NewUserToken

=item * Response: response.yaml#/NewUserToken

=back

=head3 C<GET /user/me/token/:token_name>

=over 4

=item * Response: response.yaml#/UserToken

=back

=head3 C<DELETE  /user/me/token/:token_name>

=over 4

=item * Response: C<204 NO CONTENT>

=back

=head3 C<GET /user/:target_user_id_or_email>

=over 4

=item * Requires System Admin Authentication

=item * Response: response.yaml#/UserDetailed

=back

=head3 C<< POST /user/:target_user_id_or_email?send_mail=<1|0> >>

Optionally take the query parameter C<< send_mail=<1|0> >> (default 1) - send
an email telling the user their tokens were revoked

=over 4

=item * Requires System Admin Authentication

=item * Request: input.yaml#/UpdateUser

=item * Response: response.yaml#/UserDetailed

=back

=head3 C<< DELETE /user/:target_user_id_or_email?clear_tokens=<1|0> >>

When a user is deleted all workspace permissions are removed and are
unrecoverable.

Optionally takes a query parameter C<clear_tokens> (defaults to C<1>), to also
revoke all session tokens for the user forcing all tools to log in again.

=over 4

=item * Requires System Admin Authentication

=item * Response: response.yaml#/UserDetailed

=item * Response: C<204 NO CONTENT>

=back

=head3 C<< POST /user/:target_user_id_or_email/revoke?login_only=<0|1> or ?api_only=<0|1> >>

Optionally accepts the following query parameters:

=over 4

=item * C<< login_only=<0|1> >> (default 0) - revoke only login/session tokens

=item * C<< api_only=<0|1> >> (default 0) - revoke only  API tokens

=back

By default it will revoke both login/session and API tokens. If both
C<api_only> and C<login_only> are set, no tokens will be revoked.

=over 4

=item * Requires System Admin Authentication

=item * Response: C<204 NO CONTENT>

=back

=head3 C<< DELETE /user/:target_user_id_or_email/password?clear_tokens=<login_only|0|all>&send_password_reset_mail=<1|0> >>

Optionally accepts the following query parameters:

=over 4

=item * C<clear_tokens> (default C<login_only>) to also revoke tokens for the user, takes the following possible values

=over 4

=item * C<0>, C<no>, C<false>

=item * C<login_only>, C<1> (default, for backcompat, C<1> is treated as C<login_only>)

=item * C<all> - also affects all API tokens (and thus other tools).

=back

=item * C<send_password_reset_mail> which takes C<< <1|0> >> (default C<1>). If set to C<1> this will cause an email to be sent to the user with password reset instructions.

=back

=over 4

=item * Requires System Admin Authentication

=item * Response: C<204 NO CONTENT>

=back

=head3 C<GET /user>

=over 4

=item * Requires System Admin Authentication

=item * Response: response.yaml#/UsersDetailed

=back

=head3 C<< POST /user?send_mail=<1|0> >>

Optionally takes a query parameter, C<send_mail> (defaults to C<1>) to send an
email to the user with the new password.

=over 4

=item * Requires System Admin Authentication

=item * Request: input.yaml#/NewUser

=item * Response: response.yaml#/User

=back

=head3 C<GET /user/:target_user_id_or_email/token>

=over 4

=item * Response: response.yaml#/UserTokens

=back

=head3 C<GET /user/:target_user_id_or_email/token/:token_name>

=over 4

=item * Response: response.yaml#/UserTokens

=back

=head3 C<DELETE /user/:target_user_id_or_email/token/:token_name>

=over 4

=item * Response: C<204 NO CONTENT>

=back

=head1 LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at L<http://mozilla.org/MPL/2.0/>.

=cut
# vim: set ts=4 sts=4 sw=4 et :
