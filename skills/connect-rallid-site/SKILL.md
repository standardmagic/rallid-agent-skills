---
name: connect-rallid-site
description: Connect a coding agent to a Rallid-hosted BlackRail site for scoped page work. Use when configuring a staging site URL and short-lived BlackRail page API token. Do not use for KingRail publishing, server access, theme deployment, or Rallid platform administration.
---

# Connect a Rallid site

Connect only to a Rallid-hosted **BlackRail** site. BlackRail currently supports scoped page API operations; KingRail does not yet expose a customer-safe machine publishing interface.

Before running a command, read [references/helper-location.md](references/helper-location.md) and resolve `BLACKRAIL_PAGES_HELPER` to the bundled helper's absolute installed path. Do not assume the current working directory. The helper needs Bash and curl; its authenticated connection check also needs jq. See the package README for versions and command-specific prerequisites.

## Required setup

1. Confirm the selected site is a BlackRail site and identify its **staging** URL.
2. Ask the authorized site administrator to create a short-lived API token in that site's BlackRail admin with only:
   - `pages:read`
   - `pages:edit`
3. Copy the exact approved staging origin from Rallid. Keep that pin, the request origin, and the token in the current process environment or an approved secret store:

   ```bash
   export BLACKRAIL_SITE_URL="https://staging.example.com"
   export BLACKRAIL_APPROVED_SITE_ORIGIN="https://staging.example.com"
   export BLACKRAIL_API_TOKEN="<short-lived-staging-token>"
   ```

4. Run the helper's read-only connection check before attempting page changes:

   ```bash
   "$BLACKRAIL_PAGES_HELPER" check
   ```

   The check calls authenticated `GET /api/v1/token`, rejects a token for a different canonical origin, and requires both `pages:read` and `pages:edit` in the response.

Never paste the token into source files, commit it, print it, store it in a prompt artifact, or add it to a shell profile. Avoid command tracing while a token is present.

## Boundaries

- Published-page reads are public and the helper deliberately sends no bearer token for them. The token is used only for the authenticated check and writes within its scopes.
- It does not grant media, theme, navigation, settings, plugin, database, server, SSH, deployment, or Rallid control-plane access.
- Never request or use `PLATFORM_API_KEY`, `BLACKRAIL_PROVISIONING_API_KEY`, root credentials, SSH keys, or browser session cookies.
- A staging token must not include `pages:publish`.
- Production publication requires a separate token and explicit human approval at the moment of publication. Use the bundled `publish-blackrail-pages` skill for that workflow.
- For KingRail, explain that agent publishing is managed early access and stop. Do not simulate or invent a machine publishing path.

Read [references/access-model.md](references/access-model.md) when selecting credentials, scopes, or environments.
