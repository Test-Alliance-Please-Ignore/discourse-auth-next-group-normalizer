# auth-next-group-normalizer

Discourse plugin that normalizes `discourse-oauth2-basic` group sync values from Auth Next.

It rewrites OAuth-associated group names like:

- `Group Name` -> `group-name`
- `First Second` -> `first-second`

Behavior:

- trims leading/trailing whitespace
- lowercases the name
- replaces runs of whitespace with `-`
- collapses repeated `-`
- synthesizes `test-alliance` whenever the normalized OAuth group list is non-empty
- if a Discourse group already exists with the same normalized name, automatically links it
  to the matching `oauth2_basic` associated group
- grants `admin` to users who land in configured admin groups
- sets the Discourse username from the OAuth `name` field

## Install

This directory is already structured as a Discourse plugin repository root.

If you want to use it from `app.yml`, publish the contents of this directory as its own git
repository, then add that repository to your Discourse container config.

If you want to install it manually instead, copy this directory into your Discourse installation as:

```text
plugins/auth-next-group-normalizer
```

Then rebuild/restart Discourse.

## Install via `app.yml`

Example:

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://your.git.host/auth-next-group-normalizer.git
```

Then rebuild:

```bash
cd /var/discourse
./launcher rebuild app
```

Important:

- Discourse clones plugin repositories into `$home/plugins`
- the repository root itself must contain `plugin.rb`
- you cannot point `app.yml` at a subdirectory of a larger repository
- if you want to use this plugin through `app.yml`, this directory must be the root of its own repo

## Usage

Keep your normal `discourse-oauth2-basic` setup, including:

```text
oauth2_json_groups_path = groups
```

This plugin runs on the `after_auth` hook and rewrites `auth_result.associated_groups`
before Discourse applies group sync.

If a Discourse group already exists with the normalized name, the plugin also ensures the
group is associated with the matching `oauth2_basic` provider group, so users can be added
without a separate Rails-console step.

It does not create Discourse groups automatically.

If the OAuth provider returns no groups for a user, the synthesized `test-alliance` group is
not added, and Discourse group sync will remove the associated membership on the next OAuth
login.

## Site setting

- `auth_next_group_normalizer_enabled`
- `auth_next_group_normalizer_admin_groups`

Enabled by default.

`auth_next_group_normalizer_admin_groups` defaults to:

```text
forum-admins|server-admins
```

Use `|` to configure more than one group slug:

```text
forum-admins|another-admin-group
```

Notes:

- admin is granted automatically when a user logs in via OAuth with one of those normalized groups
- admin is also granted when the user is automatically added to one of those groups
- this plugin does not automatically revoke admin when a user later leaves such a group
- username is derived from the OAuth `name` field, which should be the Auth Next primary
  character name in your setup
- existing users are renamed on OAuth login because the plugin sets `overrides_username = true`
