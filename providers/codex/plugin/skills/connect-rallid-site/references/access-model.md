# Access model

## Supported target

BlackRail exposes a page API at `/api/v1/pages` and an authenticated token-introspection endpoint at `/api/v1/token`. The site administrator creates and revokes tokens inside that BlackRail site's admin. Rallid is the hosting and customer control plane; its infrastructure credentials are never customer agent credentials.

## Staging credential

Use a short-lived token scoped to:

- `pages:read`
- `pages:edit`

Use it only with the staging site's HTTPS origin. A staging credential must not carry `pages:publish`.

Copy the exact approved staging origin from Rallid into `BLACKRAIL_APPROVED_SITE_ORIGIN`. The helper canonicalizes both origin values and refuses to send a token when the pin and request target differ. Its connection check expects `GET /api/v1/token` to return `ok`, `site_name`, `site_origin`, `scopes`, and `expires_at`; it verifies the origin and required scopes locally.

## Production credential

Production work is deliberately separate. Only after a human explicitly approves a specific publication should the authorized administrator issue a short-lived token containing `pages:edit` and `pages:publish` (plus `pages:read` only if the approved operation needs it). Pass it in `BLACKRAIL_PUBLISH_API_TOKEN` and use the production URL in `BLACKRAIL_PRODUCTION_SITE_URL`. Before writing, the publishing helper verifies the token's production origin and required scopes through `GET /api/v1/token`.

Revoke or expire production tokens after the approved publication window. Do not silently reuse approval for later changes.

## What the page API does not provide

The current page API does not provide machine access to media uploads, theme files, navigation, site settings, plugin management, arbitrary code, database operations, server deployments, or KingRail publishing. Escalate those needs to the site's authorized operator rather than broadening credentials.

## Read behavior

Page list and single-page reads expose public or published content and do not require a bearer token. The helper intentionally performs those reads anonymously. Draft reads are not currently available through this API. Preserve the local draft payload and verify the rendered staging result through the normal site preview before requesting production approval.
