# Images, files, and themes

Two capabilities that arrived after the page tools, with limits worth knowing before you start
rather than after a refusal. Every refusal below carries an `error_code`; the wording given
here is what to say to the customer.

---

# Media

## The two tools

| Tool | What it does |
| --- | --- |
| `list_media({folder?, cursor?, limit?})` | Read-only. What is already in the site's media library, with a cursor for more |
| `upload_media({filename, content_base64, alt?, folder?})` | Puts one file in the library. Returns `{id, url, ...}`. Needs `media:upload` |

## Look before you upload

`list_media()` first, always. The logo, the team photo, the shop front and last year's hero
image are usually already in the library. Reusing one costs nothing, has no rate limit, cannot
fail validation, and keeps the site from filling up with four copies of the same picture under
four names. Search it by folder when the library is large.

A row is `{id, url, filename, mime, kind, bytes, folder, managed}`. **There is no `alt` on a
row** — the library has no alt column — so you match an existing asset by its `filename` and
`folder`, not by alt text you remember writing. `mime` and `kind` tell you what it is, `bytes`
whether it is the full-size original, and `managed` whether the library owns it.

The response also carries **`usage`**, the same quota block `upload_media` returns. Read it
before a batch: it is how you find out you have eleven uploads left this hour *before* you
start converting forty photographs.

Upload only what genuinely is not there.

## Uploading

- `filename` is a plain name — letters, digits, hyphens, one extension. Not a path. If the
  file should sit somewhere in particular, that is what `folder` is for.
- `content_base64` is the file's bytes. Photographs get big fast; see the limits.
- The response's `url` is the address to put in `body_html` or in a record's `image_url`. Use
  it **exactly as returned**. Never construct a media path from an id, a filename, or a
  pattern you saw on another site — a guessed path is a broken image.
- **No approval is needed for an upload.** It puts a file in the library, not on the site.
  Nothing a visitor sees changes until a draft carrying that image is published through the
  ordinary approval flow. Say what you are about to upload anyway, before you do it.

## Alt text: `alt_is_advisory`

The `alt` you pass to `upload_media` is a note stored beside the file. **`alt_is_advisory` is
always present on an upload response**, and when it is `true` that note is *all* it is — the
theme does not print it, and an `<img>` that relies on it ships with no alt text at all.

So write the alt yourself, on the `<img>` in `body_html`:

- Meaningful image: `alt` says what a visitor would lose by not seeing it, in a sentence
  fragment, without "image of".
- Decorative image: `alt=""`, deliberately empty.

Pass `alt` to `upload_media` as well — it helps whoever opens the library later — but never
treat it as the accessible name.

## Limits

| Limit | Value |
| --- | --- |
| One file | Under the **smaller of the site's own cap and 5 MB** |
| Uploads per hour | 60 on a connection |
| Bytes per day | 200 MB on a connection |

Plan a batch of images against those numbers before you start, and tell the user when a set of
photographs will not fit. Halfway through a gallery is a bad moment to find out.

## When an upload is refused

Read `error_code` and answer accordingly. Never retry the same bytes under a different name
hoping a different answer comes back.

### `unsupported_media`

The site does not accept that kind of file. The check is on the file's actual content, not on
its extension, so renaming it changes nothing.

> Your site doesn't accept that kind of file, and renaming it won't help — the check looks at
> what's actually inside it, not at the extension. I can convert it to PNG, JPEG or WebP and
> upload that instead, if you'd like.

Offer the conversion, do it if they say yes, and say which format you converted to.

### `invalid_filename`

The name was rejected. This is usually a path, a space-heavy name, or characters the library
will not take.

> The site turned that filename down. I'll try again with a plain one.

Retry **once**, with a plain name: letters, digits and hyphens, one extension. If the original
name had directories in it, those belong in `folder`, not in `filename`.

### `too_large`

The file is over the ceiling for this route.

> That file is bigger than the upload limit I can send through, so it won't go from here. I
> can compress it and try again — the page will still look right — or you can add the original
> in your site admin under **Media** and paste the address back to me.

Offer both. If they choose compression, say what you did to it (resized to N pixels wide,
re-encoded as WebP) rather than presenting it as the same file.

### `rate_limited`

An hourly or daily ceiling. **Quote the message the tool returned** — it names the
configuration key an admin can change, and that is the useful part.

> Your site's upload limit has kicked in. Here's exactly what it said: "<the message>". The
> setting it names is one a full admin can change in the site admin; otherwise the limit
> resets on its own.

Then say how many uploads are left in the batch and offer to carry on later. Do not sit in a
retry loop waiting for the window to open.

### `permission_denied` / `missing_scope`

This connection is not allowed to upload.

> This connection isn't allowed to add files to your site. A full admin can grant that under
> **Settings → Team → Permissions**, or re-issue the connection so it includes uploads. Until
> then I'll build the page around the images and list exactly what needs adding.

Then fall back to the image rules in [content-contract.md](content-contract.md): reuse an
address that already exists, inline SVG for marks and icons, or a flagged placeholder.

### `feature_disabled`

The media library is switched off for the whole site, so there is nowhere for an upload to go.

> The media library is switched off for this site, so there's nowhere for an upload to land. A
> full admin can turn it back on in your site admin. Until then, images have to be ones
> already on the site, or simple inline graphics.

This is a site-wide setting, not something about this file or this connection. Do not offer to
re-try or to convert.

---

# Themes

A theme is how the whole site looks: templates, layout, the header and footer, the event page
and its listing, the type scale, the way a card is drawn. It ships as **one package**.

## Reading the theme that is already installed

Two layers, and you usually want both.

**The theme as a record.** `theme` is a resource, so the generic readers work on it:
`list_records({resource: 'theme'})` lists the site's themes, `get_record({resource: 'theme',
id})` returns one — key, version, palette, whether it is active. `list_resources()` reports the
theme resource with **`record_tools.save_draft` set to `stage_theme`**, not
`save_record_draft`; that mapping is the reason `record_tools` exists at all.

**The theme's actual files.**

| Tool | What it does |
| --- | --- |
| `list_theme_files({id})` | Read-only: the file paths inside an installed or staged theme version |
| `get_theme_file({id, path})` | Read-only: one of those files' contents, up to **512 KB** |

Both need **`themes:stage` plus `resources:read`**.

This is what makes "just change the footer" a real workflow instead of a rebuild:

1. `list_records({resource: 'theme'})` → the active theme's `id` (`<key>@<version>`).
2. `list_theme_files({id})` → what is in it.
3. `get_theme_file({id, path})` for the handful of files you actually need — the footer
   component, the stylesheet, `theme.json`. Do not pull the whole theme file by file; read what
   the change touches.
4. Make the edit.
5. **Build a complete package as a NEW version** — the whole folder, with `version` bumped in
   `theme.json`. There is still no partial upload: what you stage is always a full theme.
6. `stage_theme`, then `request_publish`.

Two things that will fail the upload if you carry them across from what you read:

- **Never ship the old package's `MANIFEST.sha256`**, or any `SIGNATURE` file. The installer
  generates and seals its own, and *verifies* one that is shipped — so a manifest describing
  the files before your edit fails for exactly the right reason.
- **A signed theme you have edited is a new, unsigned version.** Do not present it as the
  signed original, and do not try to preserve the signature.

## `stage_theme`

`stage_theme({zip_base64, note?})` returns:

```
{
  "id": "<key>@<version>",
  "active": false,
  "validation": { "ok": true, "messages": [] },
  "edit_url": "…",
  "next_step": "…"
}
```

- **`active` comes back `false`, always.** Staging changes nothing a visitor can see. Say that
  out loud — the customer's first fear is that you just changed their website.
- `id` is `"<key>@<version>"`, and it is what `request_publish` takes as the `id`.
- Relay `next_step` and `edit_url` as they are given. Do not describe a location of your own.
- The zip is **8 MB at most** over this connector (the whole request body is capped at 12 MB).
  That is a smaller ceiling than the site admin's own theme uploader, which takes 40 MB — so a
  package that is too big here is not necessarily too big for the owner to upload by hand.
  Keep fonts and images out of a theme that is pushing the limit.
- Needs **`themes:stage`**. Requesting activation additionally needs **`resources:edit`**.

## Building the package

**[theme-package.md](theme-package.md) is the build contract** — required files, the raw-slot
allowlist, the per-template required slots, banned constructs, `theme.json` fields, asset
paths, zip limits, and a pre-flight checklist. Work through it; a package that misses one of
those is refused, not repaired.

The design principles are not different from the ones you already follow for a page —
[content-contract.md](content-contract.md) is the reference — applied to templates rather than
to one page's body:

- Semantic structure, one `<h1>` per rendered page, headings that descend a level at a time.
- Responsive by construction: no artboard pixel widths, layouts that wrap, type on `clamp()`,
  images at `max-width: 100%`.
- The site's palette and typography as tokens, not hardcoded artboard hex values. A theme is
  where `--brand-…` values are *defined*, which is exactly why a page must never define them.
- No scripts smuggled into templates; the sanitizer that strips them from a page body is not
  the theme's licence to add them back.

Then zip the package — one top-level `<key>/` folder — and stage it. There is no partial
upload and no template-by-template edit: **a template change ships as a whole theme package**,
every time. If a customer asks you to "just change the footer", the answer is a new version of
the theme, and you say so. Bump `version` in `theme.json` when you do: re-uploading the same
key at an *older* version is refused outright, and the same version is an in-place overwrite
rather than an upgrade.

## When staging is refused: `theme_invalid`

The site validated the package and turned it down. `validation.messages` names what is wrong,
in the validator's words.

> The site checked the theme package and turned it down. Here's exactly what it flagged:
>
> — "<message>"
> — "<message>"
>
> Nothing on your site changed. I'll fix those and stage it again.

**Relay `validation.messages` verbatim**, one per line. Do not summarize them, do not argue
with the validator, and do not re-stage the identical package to see whether it passes the
second time. Fix what they name, then stage a new version.

The same applies when the call succeeds but `validation.ok` is false: read the messages out,
fix, re-stage. A staged package with failing validation is not something to request approval
for.

## Activating: the ordinary approval flow, with two differences

`request_publish({resource: 'theme', id, change_summary})` → the owner's confirmation in the
site admin → `get_approval` → `publish({approval_id})`. The five statuses behave exactly as
they do for a page.

Two things are specific to a theme:

1. **Only a full admin can approve it.** Activation changes every page on the site at once, so
   the approval desk will not take it from an editor. Say this *before* you request, so nobody
   goes looking for a button they will not find. If the person you are talking to is not a
   full admin, the honest line is that the request is waiting on one.
2. **The approval desk keeps a one-click Revert** for a theme activation. Say so. It is a
   site-wide change and the reassurance is real — it is also the reason not to oversell the
   change in the `change_summary`.

Write the `change_summary` for a person deciding whether to change how their whole site looks:
what visibly changes, what stays, and anything you know is unfinished.

## `digest_mismatch` on a theme

If the package is re-staged after the owner approves it, the approval no longer matches what
is on the server and publication is refused — the same rule as a page draft edited after
approval.

> The theme package changed after it was approved, so the approval no longer matches what's on
> the server. Nothing was activated and nothing was lost. I'll send a fresh request for the
> version that's staged now, and it needs approving again.

Request again from the staged `id`, and let the user decide when to approve.

## What themes still cannot do

- No single-template edit, as above.
- No partial upload. Reading a theme's files with `get_theme_file` does not mean you can write
  one back: an edit ships as a complete package at a new version.
- No navigation, menu, or site-settings changes — a theme decides how those are drawn, not
  what is in them.
- No deletion: there is no tool that removes a staged theme. An unwanted staged version simply
  never gets activated.
