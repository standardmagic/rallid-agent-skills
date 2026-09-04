# BlackRail page API

## Endpoints

| Operation | Method and path | Required scope |
| --- | --- | --- |
| Validate a token | `GET /api/v1/token` | Any valid token; helper verifies the expected scopes |
| List public pages | `GET /api/v1/pages` | Public; send no bearer token |
| Read a public page | `GET /api/v1/pages/{slug}` | Public; send no bearer token |
| Create a page | `POST /api/v1/pages` | `pages:edit` |
| Update a page | `PUT` or `PATCH /api/v1/pages/{slug}` | `pages:edit` |
| Delete a page | `DELETE /api/v1/pages/{slug}` | `pages:delete` |

Creating a published page, changing a draft to published, or editing an already published page also requires `pages:publish`.

The production publishing token therefore needs `pages:edit` and `pages:publish`. The staging setup deliberately omits `pages:publish`, so it cannot edit an already published page.

Deletion is intentionally outside this skill's workflow. Do not request `pages:delete` for ordinary publishing.

`GET /api/v1/token` returns `ok`, `site_name`, `site_origin`, `scopes`, and `expires_at`. The helper requires a valid bearer token and verifies the response origin. It requires `pages:read` plus `pages:edit` for the staging connection check, and `pages:edit` plus `pages:publish` in its production preflight. Invalid, revoked, and expired tokens fail the request.

All configured site values must be canonical HTTPS origins: a fully qualified DNS hostname with no user information, query, fragment, non-root path, IP literal, or non-default port. A single root slash and explicit port `443` normalize away. The helper never follows redirects.

## Supported page fields

- `title`
- `slug`
- `body_html`
- `status`
- `meta_title`
- `meta_description`
- `og_image`

Use `status: "draft"` for staging work and `status: "published"` only in a human-approved production publication.

## Current limitations

- List and single-page reads expose public or published pages, not drafts.
- The API manages page HTML and metadata only.
- It does not upload media or manage themes, navigation, settings, plugins, databases, or deploys.
- There is no supported KingRail machine publishing endpoint.

## Helper prerequisites

- Bash 3.2 or newer and curl 7.76 or newer are required for every request.
- `list` uses only Bash and curl.
- `get`, `check`, and draft writes also require jq 1.6 or newer.
- Production writes additionally require `shasum` for SHA-256 review binding.
- The helper also uses standard Unix `awk`, `date`, `mktemp`, `chmod`, `rm`, and `tr` utilities.

Authenticated requests put the bearer header in a mode-`600` temporary header file so the token is not exposed in curl's process arguments. The file is removed when the request subshell exits. Avoid shell command tracing while secrets are present.

## Production review guardrail

The helper binds a production write to a locally approved operation, slug, canonical origin, exact payload SHA-256, and future Unix expiry no more than one hour away. This detects accidental changes between review and execution. It is not a cryptographic approval and does not replace BlackRail authorization: the valid, unexpired token with `pages:edit` and `pages:publish` remains the server-side authorization boundary.

## Payload example

```json
{
  "title": "About us",
  "slug": "about",
  "body_html": "<main><h1>About us</h1><p>...</p></main>",
  "status": "draft",
  "meta_title": "About us",
  "meta_description": "Learn more about our work.",
  "og_image": ""
}
```
