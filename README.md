# Rallid agent skills

Skills for customer-controlled publishing to Rallid-hosted BlackRail sites, across two surfaces:

- **Developer surface** — Claude Code and Codex, where a bundled bash helper calls the BlackRail page API with scoped, short-lived tokens. Pages only.
- **Customer surface** — the Claude consumer app (claude.ai and desktop), where there is no shell: the skill drives a remote Rallid MCP connector's tools. Pages, plugin records (events first), media uploads, and theme packages.

The connector surface reaches one gateway address for everyone, `connect.rallid.com`, whose tool list is three gateway tools plus whatever the selected site exposes. It does not provide Rallid infrastructure access, server access, deletion of anything, plan or billing changes, or KingRail machine publishing — and nothing it can reach goes live without the site owner's approval. See [the capability matrix](docs/capability-matrix.md).

## Source layout

- `skills/` is the source of truth.
- `providers/codex/plugin/` packages the CLI skills for Codex.
- `providers/claude/plugin/` packages the CLI skills **and the connector skill** for Claude. That plugin is what Claude's unified directory installs, and the install reaches chat as well as Claude Code — chat being where the Rallid connector's tools actually live.
- `providers/claude-ai/skill/` packages the connector skill on its own, for the standalone zip a customer uploads.
- `scripts/sync-skills.mjs` copies each source skill into the providers that can run it. Codex never receives the connector skill, because Codex has no Rallid connector; the helper-driven skills never ship in the claude.ai upload. Only the CLI skills receive the generated `references/helper-location.md` — writing it into the connector skill would put a shell workflow inside a chat-only skill.

Run `node scripts/sync-skills.mjs` after changing a source skill.

## Building the claude.ai upload

```bash
node scripts/build-claude-ai-zip.mjs
```

That re-syncs the providers and writes `dist/publish-rallid-site.zip` with the skill folder at the ZIP root, which is the layout the Claude app's **Settings → Capabilities → Skills → Upload skill** expects. It needs Node and the system `zip`. Customer-facing install instructions live in [docs/install-claude-app.md](docs/install-claude-app.md), which the hosting portal can link or embed.

## Tests

```bash
node tests/package-structure.mjs
bash tests/helper-safety.sh
```

## Runtime prerequisites

The request helper supports Bash 3.2 or newer and curl 7.76 or newer. Public page listing needs only those two tools. Token checks, single-page reads, and draft writes also need jq 1.6 or newer; production writes additionally need `shasum`. Standard Unix `awk`, `date`, `mktemp`, `chmod`, `rm`, and `tr` utilities are also used.

Public page reads are anonymous. Authenticated checks and writes put the bearer header in a mode-`600` temporary file, not curl's process arguments, and remove that file after the request.

## Local installation

This repository is local-only until Rallid publishes an approved marketplace source. Do not substitute a made-up public repository URL.

For Codex:

```bash
codex plugin marketplace add <path-to-rallid-agent-skills>
codex plugin add rallid-publisher@rallid-agent-skills
```

For Claude Code:

```bash
claude plugin marketplace add <path-to-rallid-agent-skills>
claude plugin install rallid-publisher@rallid-agent-skills
```

For the Claude consumer app there are two routes to the same skill: installing the `rallid-publisher` plugin from Claude's unified directory, which carries it into chat, or uploading the built zip at Settings → Capabilities → Skills. Either way the customer still adds the connector at `connect.rallid.com`; walk them through [docs/install-claude-app.md](docs/install-claude-app.md).

## Skills

Claude Code and Codex (helper-driven, token-based):

- `connect-rallid-site` pins an approved staging origin and validates a narrow token through `GET /api/v1/token`.
- `publish-blackrail-pages` creates and updates staged drafts, then requires explicit human approval and a separate production token before publication. Its operation/origin/slug/payload-digest/expiry binding is a local review guardrail; the scoped BlackRail token remains the authorization boundary.

Claude consumer app and Claude Code chat (connector-driven, no shell and no tokens in the conversation):

- `publish-rallid-site` picks the active site through the gateway (`list_sites` → `select_site`, with `create_site` for an account whose only option is a 14-day trial), verifies it with `check_connection` (and keeps its `admin_url`), reads the site's palette and typography with `get_design_context`, inventories pages, converts an attached design export into site content, stages it with `save_draft`, and hands the customer the returned `edit_url`. It also drafts plugin records through the generic resource tools (`list_resources` → `list_records` → `get_record` → `save_record_draft`, with `events` as the first resource; an update is a **patch** the server merges onto the stored record, and both readers and the writer return an `edit_url` for the owner), uploads images with `upload_media` after checking `list_media` and its `usage` block, reads an installed theme's files with `list_theme_files` / `get_theme_file`, and builds and stages theme packages with `stage_theme` against the engine's declarative theme contract (`references/theme-package.md`: required files, the raw-slot allowlist, banned constructs, `theme.json` fields and how `<key>@<version>` is derived, zip limits, and a pre-flight checklist).

  Publication of anything runs `request_publish` (by `slug`, or by `resource` and `id`) → **a full admin's** confirmation in the site admin → `get_approval` → `publish`, with no bypass for any connection and no scope that grants it; `approver` is always `full_admin`, for every resource. The skill degrades gracefully on any missing scope (`pages:read`, `pages:edit`, `resources:read`, `resources:edit`, `media:upload`, `themes:stage`) or missing tool, relays admin-only page refusals, all three plugin refusal kinds and theme validation messages verbatim, escalates an `internal_error` by its `err_…` reference instead of retrying, never invents a link, and stops with install instructions when no Rallid connector is present.

Tokens belong in the current process environment or an approved secret store. Never commit them or place them in agent artifacts. The Claude app surface never handles a token at all — the connector holds the grant, and the customer is told not to paste credentials into the chat.
