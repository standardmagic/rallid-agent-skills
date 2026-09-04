---
name: publish-blackrail-pages
description: Draft, review, update, and human-approve page content on a Rallid-hosted BlackRail site through its scoped page API. Use for BlackRail page publishing only; do not use for themes, media, server deploys, Rallid infrastructure, or KingRail.
---

# Publish BlackRail pages

Work staging first. Treat content drafting, staging verification, and production publication as separate decisions.

Before running a command, read [references/helper-location.md](references/helper-location.md) and resolve `BLACKRAIL_PAGES_HELPER` to the bundled helper's absolute installed path. Do not assume the current working directory. Read [references/page-api.md](references/page-api.md) for endpoint behavior and command-specific prerequisites.

## Workflow

1. If the site is not connected, use the bundled `connect-rallid-site` skill first.
2. Inventory currently published pages with `"$BLACKRAIL_PAGES_HELPER" list` and inspect relevant public pages with `get <slug>`. These public reads send no bearer token.
3. Prepare a JSON payload and summarize the proposed title, slug, status, metadata, and material content changes for the user.
4. Create or update the page as a **draft** on staging using the `pages:read` and `pages:edit` token:

   ```bash
   "$BLACKRAIL_PAGES_HELPER" create-draft ./page.json
   "$BLACKRAIL_PAGES_HELPER" update-draft page-slug ./page.json
   ```

5. Verify the staging result through the site's normal preview and report any limitations. Draft reads are not available through the current API, so retain the local payload as the review source.
6. Before asking for approval, stop editing the payload. Compute its SHA-256 with `shasum -a 256`, then show the user the exact production origin, operation (`publish-new` or `publish-update`), slug, digest, expiry window, and a concise change summary. Ask for explicit approval of those exact values. A prior approval does not cover a changed byte, operation, slug, origin, or later window.
7. Only after that approval, use a separate short-lived production token containing `pages:edit` and `pages:publish`. Set the local review guardrail fields to the approved values and choose the matching command:

   ```bash
   export BLACKRAIL_PRODUCTION_SITE_URL="https://www.example.com"
   export BLACKRAIL_PUBLISH_API_TOKEN="<short-lived-production-token>"
   export BLACKRAIL_APPROVED_OPERATION="publish-update"
   export BLACKRAIL_APPROVED_PAGE_SLUG="page-slug"
   export BLACKRAIL_APPROVED_ORIGIN="https://www.example.com"
   export BLACKRAIL_APPROVED_PAYLOAD_SHA256="<exact-digest-shown-for-approval>"
   export BLACKRAIL_APPROVAL_EXPIRES_AT_EPOCH="$(( $(date +%s) + 600 ))"
   "$BLACKRAIL_PAGES_HELPER" publish-update page-slug ./page.json
   ```

   Use `publish-new ./page.json` only when that exact operation was approved. The helper rejects guardrails more than one hour in the future, then verifies the production token's origin and `pages:edit` plus `pages:publish` scopes through `GET /api/v1/token` before writing.
8. Report the result and recommend revoking the production token. Clear the production token and guardrail variables from the process environment.

## Safety requirements

- Never add `pages:publish` to the staging token.
- Never infer production approval from a request to draft, preview, test, connect, or fix content.
- Never print, commit, persist, or include bearer tokens in generated artifacts.
- Never pass a bearer token as a curl argument. The helper writes its authorization header to a mode-`600` temporary file and removes it after the request.
- Do not follow redirects with authorization headers.
- Do not claim support for media, themes, navigation, settings, plugins, arbitrary code, server deployment, or KingRail machine publishing.
- Never request Rallid platform keys, provisioning keys, SSH access, or browser cookies.
- A staging token cannot edit an already published page because that operation also requires `pages:publish`. Create a review draft with a distinct slug or ask an authorized operator to prepare a draft; do not broaden the staging token.
- Treat the operation/origin/slug/digest/expiry checks as a **local review guardrail**, not as an authorization grant or a signed approval. Anyone controlling the local process can change those variables. The BlackRail server's valid, unexpired, correctly scoped production token remains the authorization boundary.

Use the bundled helper rather than reconstructing authenticated curl commands when it fits the task.
