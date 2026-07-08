# Repository Guidelines

## Project Structure & Module Organization
`plugin.rb` contains the full runtime implementation. The `AuthNextGroupNormalizer` module normalizes OAuth group slugs, derives identity fields, and hooks into Discourse events such as `:after_auth` and `:user_added_to_group`. `config/settings.yml` defines plugin site settings, and `config/locales/server.en.yml` provides the admin-facing labels for those settings. `README.md` covers installation and behavior. Keep `plugin.rb` at the repository root so the repo remains installable as a standalone Discourse plugin.

## Build, Test, and Development Commands
Use `ruby -c plugin.rb` for a quick syntax check before pushing changes. Run `git diff --check` to catch trailing whitespace and other patch formatting issues. To exercise changes in a real Discourse instance, place this repository at `plugins/auth-next-group-normalizer` and rebuild with `cd /var/discourse && ./launcher rebuild app`. There is no standalone app runner in this repository; validation happens through a Discourse install with OAuth group sync enabled.

## Coding Style & Naming Conventions
Follow the existing Ruby style in `plugin.rb`: tabs for indentation, `snake_case` for methods, early returns, and small helper methods grouped under `module ::AuthNextGroupNormalizer`. Keep normalized group identifiers in lowercase kebab-case, for example `forum-admins`. New site settings should use the `auth_next_group_normalizer_` prefix and always ship with matching locale entries.

## Testing Guidelines
No automated spec suite exists in this repository today. For each change, manually verify group normalization, synthesized group behavior (`test-alliance`), local `AssociatedGroup` linking, and admin or moderator grants. When a change depends on OAuth payload structure, include the tested payload shape or example group list in the PR description.

## Commit & Pull Request Guidelines
Recent history uses short lowercase prefixes such as `added:` and `changed:` followed by a concise description. Keep commit subjects brief, imperative, and focused on one behavior change. Pull requests should describe the affected auth flow, any site setting changes or default changes, and the exact manual verification performed. Include screenshots only when admin setting text or other visible UI copy changed.

## Security & Configuration Notes
This plugin can grant `admin` and `moderator`, so changes to role-assignment logic are sensitive. Avoid logging raw OAuth account data unless it is redacted, and treat expansions to privileged default groups as deliberate, reviewed changes.
