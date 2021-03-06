# NAME

Conch::Route::User

# METHODS

## routes

Sets up the routes for /user:

Unless otherwise noted, all routes require authentication.

### `GET /user/me`

- Response: response.yaml#/UserDetailed

### `POST /user/me/revoke?send_mail=<1|0>& login_only=<0|1> or ?api_only=<0|1>`

Optionally accepts the following query parameters:

- `send_mail=<1|0>` (default 1) - send an email telling the user their tokens were revoked
- `login_only=<0|1>` (default 0) - revoke only login/session tokens
- `api_only=<0|1>` (default 0) - revoke only  API tokens

By default it will revoke both login/session and API tokens. If both
`api_only` and `login_only` are set, no tokens will be revoked.

- Request: input.yaml#/UserSettings
- Response: `204 NO CONTENT`

### `POST /user/me/password?clear_tokens=<login_only|0|all>`

Optionally takes a query parameter `clear_tokens`, to also revoke the session
tokens for the user, forcing the user to log in again. Possible options are:

- `0`, `no`, `false`
- `login_only`, `1` (default, for backcompat, `1` is treated as `login_only`)
- `all` - also affects all API tokens (and thus other tools).

If the `clear_tokens` parameter is set to `0`, `no`, `false` then
`204 NO CONTENT` will be returned but the user session will remain..

- Request: input.yaml#/UserSettings
- Response: `204 NO CONTENT` (The user session is terminated).

### `GET /user/me/settings`

- Response: response.yaml#/UserSettings

### `POST /user/me/settings`

- Request: input.yaml#/UserSettings
- Response: `204 NO CONTENT`

### `GET /user/me/settings/:key`

- Response: response.yaml#/UserSetting

### `POST /user/me/settings/:key`

- Request: input.yaml#/UserSetting
- Response: `204 NO CONTENT`

### `DELETE /user/me/settings/:key`

- Request: input.yaml#/DeviceSetting
- Response: `204 NO CONTENT`

### `GET /user/me/token`

- Response: response.yaml#/UserTokens

### `POST /user/me/token`

- Response: input.yaml#/NewUserToken
- Response: response.yaml#/NewUserToken

### `GET /user/me/token/:token_name`

- Response: response.yaml#/UserToken

### `DELETE  /user/me/token/:token_name`

- Response: `204 NO CONTENT`

### `GET /user/:target_user_id_or_email`

- Requires System Admin Authentication
- Response: response.yaml#/UserDetailed

### `POST /user/:target_user_id_or_email?send_mail=<1|0>`

Optionally take the query parameter `send_mail=<1|0>` (default 1) - send
an email telling the user their tokens were revoked

- Requires System Admin Authentication
- Request: input.yaml#/UpdateUser
- Response: response.yaml#/UserDetailed

### `DELETE /user/:target_user_id_or_email?clear_tokens=<1|0>`

When a user is deleted all workspace permissions are removed and are
unrecoverable.

Optionally takes a query parameter `clear_tokens` (defaults to `1`), to also
revoke all session tokens for the user forcing all tools to log in again.

- Requires System Admin Authentication
- Response: response.yaml#/UserDetailed
- Response: `204 NO CONTENT`

### `POST /user/:target_user_id_or_email/revoke?login_only=<0|1> or ?api_only=<0|1>`

Optionally accepts the following query parameters:

- `login_only=<0|1>` (default 0) - revoke only login/session tokens
- `api_only=<0|1>` (default 0) - revoke only  API tokens

By default it will revoke both login/session and API tokens. If both
`api_only` and `login_only` are set, no tokens will be revoked.

- Requires System Admin Authentication
- Response: `204 NO CONTENT`

### `DELETE /user/:target_user_id_or_email/password?clear_tokens=<login_only|0|all>&send_password_reset_mail=<1|0>`

Optionally accepts the following query parameters:

- `clear_tokens` (default `login_only`) to also revoke tokens for the user, takes the following possible values
    - `0`, `no`, `false`
    - `login_only`, `1` (default, for backcompat, `1` is treated as `login_only`)
    - `all` - also affects all API tokens (and thus other tools).
- `send_password_reset_mail` which takes `<1|0>` (default `1`). If set to `1` this will cause an email to be sent to the user with password reset instructions.

- Requires System Admin Authentication
- Response: `204 NO CONTENT`

### `GET /user`

- Requires System Admin Authentication
- Response: response.yaml#/UsersDetailed

### `POST /user?send_mail=<1|0>`

Optionally takes a query parameter, `send_mail` (defaults to `1`) to send an
email to the user with the new password.

- Requires System Admin Authentication
- Request: input.yaml#/NewUser
- Response: response.yaml#/User

### `GET /user/:target_user_id_or_email/token`

- Response: response.yaml#/UserTokens

### `GET /user/:target_user_id_or_email/token/:token_name`

- Response: response.yaml#/UserTokens

### `DELETE /user/:target_user_id_or_email/token/:token_name`

- Response: `204 NO CONTENT`

# LICENSING

Copyright Joyent, Inc.

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).
