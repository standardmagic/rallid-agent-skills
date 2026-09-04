# Building a theme package that `stage_theme` will accept

A theme is **declarative**: a folder of manifest, one stylesheet, and logic-free HTML. There
is no theme code — no PHP, no JavaScript, no build step. The engine renders your templates by
substituting `{{slots}}`, your stylesheet consumes the site's brand tokens, and your header,
footer and starter pages seed into the CMS as content the owner can edit afterwards.

Follow this file as a build checklist. Every rule here is enforced somewhere — at upload, at
activation, or at render — and a package that breaks one is refused rather than repaired.

## Before you build: read the theme that is already there

`theme` is a resource like any other, so the generic tools work on it:

- `list_records({resource: 'theme'})` — the themes on this site, with the active one marked.
- `get_record({resource: 'theme', id})` — one theme's manifest and metadata.
- `list_resources()` reports the theme resource with **`record_tools.save_draft` set to
  `stage_theme`**, not `save_record_draft`. That is the whole reason `record_tools` exists:
  read a resource generically, write it with the tool it names.

And the theme's **files** are readable too, with `themes:stage` plus `resources:read`:

- `list_theme_files({id})` — every file path in an installed or staged theme version.
- `get_theme_file({id, path})` — one file's contents, up to **512 KB**.

Read before you write, exactly as you would for a page. Knowing the active theme's `key`,
`version` and palette decides whether you are shipping a **new** theme or a **new version of
the existing one**, and those are different answers to the customer.

### Changing an existing theme

"Just darken the footer" is a read-edit-repackage loop, not a rebuild:

1. `list_records({resource: 'theme'})` → the active theme's `id`, which is `<key>@<version>`.
2. `list_theme_files({id})` → the paths.
3. `get_theme_file({id, path})` for the files the change actually touches — the footer
   component, `assets/theme.css`, `theme.json`. Read what you need, not the whole tree.
4. Make the edit.
5. Rebuild the **complete** package with `version` bumped in `theme.json`, and stage that.
   There is no partial upload; what you stage is always a whole theme at a new version.

Two rules specific to repackaging something you read back:

- **Do not carry the old `MANIFEST.sha256` across**, or any `SIGNATURE` file. The installer
  generates and seals its own and *verifies* a shipped one, so a manifest describing the files
  as they were before your edit fails the upload — correctly.
- **A signed theme you have edited is a new, unsigned version.** That is fine and expected.
  Do not present it as the signed original and do not try to preserve the signature.

## File layout

The zip contains **exactly one top-level folder**, and that folder's name **is the theme key**
(`^[a-z0-9][a-z0-9-]*$`, up to 64 characters):

```
<key>/
  theme.json
  assets/
    theme.css                        the entire stylesheet, one file
    ...                              optional images and fonts
  templates/public/
    custom-page.html                 every ordinary page
    form-page.html                   Forms plugin pages
    not-found.html                   404
    protected-page.html              password-gated unlock screen
    form-verification.html           double-opt-in confirmation screen
  components/
    site-header.html
    site-footer.html
  starter/                           optional, strongly recommended
    home.html  about.html  contact.html
  AUTHORING.md                       optional
```

All five templates are **required** — a missing one fails the upload. The two components are
technically optional (the theme falls back to template markup) but ship both.

**Never include** `MANIFEST.sha256`, any `SIGNATURE` file, `SBOM.cdx.json`,
`BUILD-PROVENANCE.json` or `MANIFEST.sha256.sig`. The installer generates and seals its own,
and it *verifies* a shipped one — so a stale manifest you did not regenerate fails the upload
for no reason at all. This bites hardest when you have read an existing theme back with
`get_theme_file`: drop its seal, because an edited signed theme is a new unsigned version.

**Never include** `.php`, `.js` or `.mjs` files, or a `.py` script. Allowed extensions:
`css html htm md markdown txt json map png jpg jpeg webp avif gif svg ico woff woff2 ttf otf`,
plus extensionless `LICENSE`, `README` and `NOTICE`. Anything else is a disallowed file type.
Symlinks are rejected.

## `<key>@<version>`

`stage_theme` returns `id: "<key>@<version>"`, and that is the id `request_publish` takes.
Both halves come from the package you built:

- **`key`** — the zip's single top-level folder name. If the zip instead has `theme.json` at
  its root, the key comes from `theme.json`'s `key` field. In the normal single-folder layout
  the folder name wins and a mismatched `key` field is ignored — but keep them identical
  anyway, because the validator fails a mismatch before the engine ever forgives it.
- **`version`** — `theme.json`'s `version` field.

## `theme.json`

```json
{
  "name": "Harborlight",
  "key": "harborlight",
  "type": "declarative",
  "version": "1.0.0",
  "requires": "1.0.0",
  "tested_up_to": "1.0.0",
  "author": "…",
  "description": "One paragraph, shown in the theme picker.",
  "supports": ["forms"],
  "stylesheet": "assets/theme.css",
  "snapshot_url": "/",
  "template": "custom-page",
  "tokens": {
    "brand_primary_color": "#22443B",
    "brand_accent_color": "#C2703E",
    "brand_background_color": "#F5F4EF",
    "brand_panel_color": "#FFFFFF",
    "brand_text_color": "#191E1C"
  },
  "starter": {
    "homepage": "home",
    "pages": [
      { "slug": "home", "title": "Home", "file": "starter/home.html", "meta_description": "…" },
      { "slug": "about", "title": "About", "file": "starter/about.html" },
      { "slug": "contact", "title": "Contact", "file": "starter/contact.html" }
    ]
  }
}
```

- **`"type": "declarative"` is mandatory.** Any other type is refused unless the operator has
  deliberately enabled trusted PHP, which is not a thing to rely on or suggest.
- **`version` is required, and it must go up.** The grammar is `1`, `1.2`, `1.2.3`, `1.2.3.4`,
  optionally with `-prerelease` and/or `+build`, 64 characters at most. Uploading a version
  **older** than the one installed under the same key is refused — downgrading in place is not
  supported. Re-uploading the **same** key at the same or a higher version upgrades in place
  and the previous version is kept server-side. So when you revise an existing theme, bump the
  version; when you forget, the upload either no-ops confusingly or is refused.
- **`requires`** — the minimum engine version. Omitting it is allowed but produces a warning;
  a `requires` newer than the site's engine is a hard refusal.
- **`tested_up_to`** older than the running engine installs with a warning, not an error.
- **`stylesheet`** must live under `assets/` and must exist.
- **`tokens`** keys must match `brand_[a-z_]+` — lowercase and underscores only. A digit or a
  dash makes the key **silently ignored** rather than an error, which is worse. Tokens seed
  the site palette once at activation; the owner's Branding edits win from then on.
- **`starter.pages[].file`** must start with `starter/` and must exist; slugs are
  `[A-Za-z0-9][A-Za-z0-9_-]*`; `starter.homepage` must name one of the declared slugs.

## Templates

Every template is a complete `<!doctype html>` document with two substitution forms:

- `{{name}}` — a value, **always HTML-escaped**. Safe anywhere, attributes included.
- `{{{name}}}` — a raw engine-composed fragment, and **only these names are legal**:

  `headMeta`, `brandCss`, `adminBar`, `siteHeader`, `siteFooter`, `menuHtml`, `body`,
  `published`, `adminEdit`, `poweredByFooter`, `formAssets`, `analyticsAssets`, `mapAssets`,
  `stateAssets`, `inlineEditorAssets`, `fields`, `formDataAttrs`, `safeError`, `extensionHtml`

  **Any other name in triple braces throws at render time.** Inventing a raw slot is one of
  the easiest ways to ship a theme that installs and then breaks the site.

**Banned anywhere in a template**, comments included, because the file is scanned raw:
`<?`; `<script>`, `<iframe>`, `<object>`, `<embed>`, `<applet>`, `<base>`, `<portal>` (opening
*or* closing, and with whitespace variants like `< script`); any `on…=` event attribute;
`javascript:` and `vbscript:` URLs; `data:text/html` and `data:text/javascript` URLs;
`<meta http-equiv>`. A template is capped at **1 MiB**.

`<link>` tags are fine — one web-font family plus `rel="preconnect"` if the design needs it.

**There are no conditionals and no loops.** Booleans stringify to `"1"` or `""`, so branch
with an attribute and CSS:

```html
<main class="th-main" data-br-ve="{{isVeLayout}}" data-br-home="{{isHomepage}}">
```

That one pattern covers both special layouts: a visual-editor page whose body is already full
designed sections, and the hero-led homepage.

### What each template must contain

Content pages carry the full shell. Utility screens are deliberately **self-contained** small
documents with their own inline `<style>` — do not paste the content-page shell onto them, and
do not use a slot the engine never passes to that template.

**`custom-page.html`** must contain, as raw slots: `headMeta`, `brandCss`, `adminBar`,
`inlineEditorAssets`, `body`, `siteHeader`, `siteFooter`, `formAssets`, `analyticsAssets`,
`mapAssets`, `stateAssets`, `adminEdit`, `poweredByFooter` — plus `{{themeCss}}` as a
stylesheet link and `{{pageRootAttr}}`.

- Head order matters: `<meta charset>`, `<meta name="viewport">`, `{{{headMeta}}}`,
  `<link rel="stylesheet" href="{{themeCss}}">`, then `{{{brandCss}}}` **after** your
  stylesheet so per-page inlined CSS can win.
- `{{{adminBar}}}` goes immediately after `<body>`.
- `{{pageRootAttr}}` is a bare attribute name the editors bind to; it must sit on the element
  that **directly wraps** `{{{body}}}`. Without it the visual editor cannot bind.
- The asset slots go before `</body>`.

**`form-page.html`** must contain: `headMeta`, `brandCss`, `adminBar`, `formAssets`, `fields`,
`formDataAttrs` — plus `{{themeCss}}`. It receives only `formAssets` at the end of `<body>`
(never the analytics/map/state/inline-editor ones). Keep the structural contract: a
`<form {{{formDataAttrs}}}>`, the `{{{fields}}}` slot, the `_gotcha` honeypot input, and a
status element carrying `id="{{statusId}}"` and the `{{formStatusAttr}}` attribute. The last
two are advisory in the validator and load-bearing in real life — drop the honeypot and spam
filtering weakens; drop the status element and submitters see no feedback.

**`not-found.html`** receives exactly `{{{headMeta}}}`, `{{{adminBar}}}`, `{{eyebrow}}`,
`{{title}}`, `{{{body}}}`, `{{href}}`, `{{button}}`, `{{themeCss}}`, `{{{brandCss}}}`. The home
link is `{{href}}` with `{{button}}` as its label — **not** `{{publicUrl}}`, which this
template never receives.

**`protected-page.html`** receives `{{{brandCss}}}` (no `{{themeCss}}`), the unlock
`<form method="post">` whose password field names are load-bearing, and `{{{safeError}}}` for
the engine's error fragment.

**`form-verification.html`** receives exactly `{{safeTitle}}`, `{{safeMessage}}`,
`{{siteName}}`, `{{publicUrl}}`, `{{accent}}` — and neither `themeCss` nor `brandCss`, so its
colours can only come from its own inline CSS. The confirmation text is `{{safeMessage}}`;
this template is never given `body`.

A slot the engine does not pass renders **empty rather than erroring**, so a wrong slot name in
double braces fails silently. Check every one against the lists above.

## Components: the editable header and footer

`components/site-header.html` and `components/site-footer.html` seed into the CMS as real,
editable components.

- The root element must keep the class `comp-site-header` / `comp-site-footer` **and** the
  `data-component-root` attribute. Layer your own classes on top of those, never instead.
- First line `<!-- title: Site Header -->` sets the label in the admin.
- `{{SITE_NAME}}` and `{{CONTACT_CTA}}` are substituted at seed time. Use them; never hardcode
  the customer's business name into a component or a starter page.
- **No scripts** — a mobile menu is a `<details>` disclosure, which is keyboard-accessible for
  free.
- Navigation links are plain hrefs matching your starter slugs.
- Re-activation refreshes only the components the operator has not edited.

## Starter content

Each `starter/*.html` file is one page's body — ordinary markup the visual editor can click
into, reorder and delete.

- Flat, well-named `<section>` blocks from one small vocabulary of your own classes. A
  full-bleed section owns an inner max-width wrapper, so it works both on the full-bleed
  homepage and inside the constrained page wrap.
- `data-br-name="Hero"`-style labels on every top-level section and on repeated cards and
  buttons — these become the editor's layer names.
- `h2`/`h3` only: the template owns the `<h1>`. No `id` attributes, no scripts, decorative SVG
  gets `aria-hidden="true"`, every `<nav>` gets an `aria-label`.
- Real copy for the customer's subject, never lorem ipsum, and never invented facts.
- Starter pages seed **only into an empty site** (zero custom pages), so they can never
  overwrite anyone's content.

## CSS and brand tokens

The engine inlines these custom properties on every page:

`--brand-primary`, `--brand-accent`, `--brand-bg` (alias `--brand-background`), `--brand-panel`,
`--brand-text`, `--brand-muted`, `--brand-rule`, `--brand-on-primary`, `--brand-on-accent`.

- **Never declare a `--brand-*` value.** Themes consume brand tokens; declaring one is a hard
  validation failure. Read them with your palette as the fallback —
  `var(--brand-primary, #22443B)` — and define your own local aliases (`--th-…`) once at
  `:root`, then use those everywhere.
- The fallbacks in your CSS and the values in `theme.json` `tokens` must be **identical**.
- Style the public Forms markup (`form[data-blackrail-form]`, its labels, inputs, buttons and
  status element) so forms look native rather than unstyled.
- Responsive and accessible without exception: `clamp()` type, grids that collapse around
  640–680px, no horizontal scroll at 375 / 768 / 1280, visible `:focus-visible` outlines, 44px
  touch targets, real contrast.

## Asset paths

Every asset must exist under `assets/` and be addressed as
**`/blackrail-theme-assets/assets/…`** — the default theme-asset route. A bare `/assets/…`
path is a **site** path, not a theme path, and 404s wherever the theme is installed; the
validator fails it explicitly. Operators can remap the prefix, so write the default and let
the engine rewrite. A `url()` in CSS that resolves outside `assets/` is a failure, and a
referenced asset that does not exist is a failure.

## Zip and upload limits

- One top-level `<key>/` folder. Not two folders, not loose files beside the folder.
- **Over this connector, `stage_theme` accepts a zip of at most 8 MB** — the whole request body
  is capped at 12 MB, and the base64 encoding is what eats the difference. This is the limit
  that will actually stop you.
- The engine's own **40 MB / 3000 entries / 128 MB expanded** limits apply to the site admin's
  theme uploader, not to this route. So a package too large to stage here may still be one the
  owner can upload by hand — say that rather than declaring it impossible.
- Each template at most **1 MiB**; `get_theme_file` reads at most **512 KB** of one file.
- `__MACOSX`, `.DS_Store`, `Thumbs.db` and `._*` entries are ignored, but keep them out.

Base64-encode that zip as `zip_base64`. Fonts and photographs are what push a theme past 8 MB:
a site's photographs belong in the media library, not in its theme.

## Pre-flight checklist — run through this before calling `stage_theme`

1. One top-level folder, named as the key, matching `^[a-z0-9][a-z0-9-]*$`.
2. `theme.json` parses; `"type": "declarative"`; `key` equals the folder name; `version` is
   present, well-formed, and **higher than the installed version** if this key already exists.
3. All five `templates/public/*.html` present; both components present.
4. Every `{{{raw}}}` name is in the allowlist; every required slot for that template is
   present; `custom-page.html` has `{{pageRootAttr}}` on the element wrapping `{{{body}}}`;
   `custom-page.html` and `form-page.html` link `{{themeCss}}`.
5. No banned construct in any HTML or CSS file — script/iframe/object/embed/applet/base/portal
   (opening or closing), `<?`, `on…=`, `javascript:`/`vbscript:`, `data:text/html`,
   `<meta http-equiv>`.
6. No `.php`, `.js`, `.mjs`, `.py`; no disallowed file types; no symlinks.
7. No `MANIFEST.sha256`, SBOM, provenance or `SIGNATURE` file — including one you read back
   out of the theme you are revising.
8. Components keep `comp-site-header` / `comp-site-footer` and `data-component-root`.
9. No `--brand-*` declaration in the CSS; every colour is a `var(--brand-…, fallback)` read;
   fallbacks match `theme.json` `tokens` exactly.
10. Every referenced asset exists and uses `/blackrail-theme-assets/assets/…`.
11. `starter.pages[].file` paths all exist under `starter/`; `starter.homepage` is one of them.
12. Starter pages use `{{SITE_NAME}}` / `{{CONTACT_CTA}}`, `h2`/`h3` only, no `id`s, and
    `data-br-name` labels.
13. The zip is **8 MB or less**.
14. Sanity-check the design at 375 / 768 / 1280 in your head, and tab through the header.

Then `stage_theme({zip_base64, note?})`. If it comes back `theme_invalid`, or with
`validation.ok` false, the messages name the exact rule that broke: relay them verbatim, fix
those, and stage again. A rejected package never installed, so the version does not need to
move for the retry — bump the version when the *theme* changes, not when a validation fix
does. See [media-and-themes.md](media-and-themes.md) for the activation flow and the
customer-facing wording.
