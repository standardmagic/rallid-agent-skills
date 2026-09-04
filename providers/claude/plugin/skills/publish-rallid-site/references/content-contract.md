# The content contract

What a page payload must look like before you call `save_draft`. A design export is a
reference; this is the contract the site actually accepts.

## The payload

```json
{
  "title": "About us",
  "slug": "about",
  "body_html": "<section>…</section>",
  "meta_title": "About us",
  "meta_description": "A short, plain sentence describing this page.",
  "og_image": ""
}
```

- `title` is the page's name in the site admin and, on most themes, the heading the visitor
  sees at the top of the page.
- `slug` is the address: lowercase letters, digits and hyphens, no spaces, no file extension,
  no leading slash. `about`, `our-services`, `contact`. A slug is an identity — changing it on
  an existing page creates a second page instead of renaming the first, and any link or
  bookmark to the old address keeps pointing at the old page. Always say this before doing it.
- `body_html` is the page's content only. Optional fields may be omitted, but omitting
  `meta_description` on a page that had one usually loses it — carry the existing value across
  when you are not deliberately changing it.

## `body_html`: content only, and semantic

Include only what belongs inside the page:

- **No** `<html>`, `<head>`, `<body>`, `<title>`, or `<meta>` — the site supplies the document.
- **No** site header, nav, logo bar, or footer — the theme supplies those. Importing them
  gives the visitor two of each.
- **No** `<script>`, `<iframe>`, `<object>`, `<embed>`, `on…=` handlers, or `javascript:`
  URLs. The site sanitizes `body_html` on arrival and strips them, so anything that depends on
  them silently breaks. Never promise behaviour that needs them.
- **No** `id` attributes (they collide with the theme and the editors) and no `style` block for
  the whole page.

Build the page out of flat, well-named `<section>` blocks — hero, section, cards, split,
band, call to action — using a small, consistent vocabulary of class names. Prefer the class
names the site already uses: read an existing page with `get_page` first and match it. Lists
are `<ul>`/`<ol>`, quotes are `<blockquote>`, buttons that navigate are `<a>`, and decorative
inline `<svg>` carries `aria-hidden="true"`. Give any in-page `<nav>` an `aria-label`.

## Headings

One `<h1>` per rendered page, and the theme usually prints it from `title`. Check before you
guess: read an existing published page with `get_page` and see whether its `body_html`
contains an `<h1>`.

- If existing pages start at `<h2>`, yours does too — the design's big hero headline becomes
  the page `title`, and the hero's `<h2>` carries the supporting line.
- If existing pages do include their own `<h1>`, match that convention.

Below that, descend one level at a time — `h2` then `h3` — and never skip a level or pick a
heading level for its size. A section's heading describes the section; if it exists only to be
big, it is a paragraph with a class.

## Responsive by construction

Artboards are fixed-width documents. A page that keeps those numbers is broken on a phone,
which is where most of this customer's visitors are.

- **No fixed pixel widths or heights** carried over from the artboard — no `width: 1440px`,
  no `min-height` copied off a board, no fixed-width columns.
- **No absolute positioning** to place a design element, and no negative margins used as
  layout.
- Constrain text with a readable maximum (`max-width` in `ch` or `rem`), not a pixel canvas.
- Multi-column areas are grid or flex layouts that **wrap** to one column on narrow screens.
- Type scales with `clamp()` rather than sitting at the artboard's desktop size.
- Images and inline SVG take `max-width: 100%` and `height: auto`.
- Tables and anything genuinely wide scroll inside their own container, so the page body never
  scrolls sideways.
- Sanity-check the result at roughly 375, 768 and 1280 pixels wide in your head before saving,
  and mention anything you are unsure of.

## Palette and typography belong to the site

The artboard's colours and fonts are a **direction**, not the page's styling. The site already
has a palette and a type scale, and a page that hardcodes the artboard's hex values stops
matching the rest of the site the moment the owner changes their branding.

**Call `get_design_context()` before converting anything.** It reports the site's real brand
basics — colours and fonts from its settings — and those are what the page honours. If the tool
is unavailable, fall back to inferring the conventions from an existing page read with
`get_page`, and tell the user which page you matched.

- Do not paste the artboard's inline `style` attributes into `body_html`.
- Do not set a page-wide font family, background colour, or text colour.
- Where a colour is genuinely part of the content (an accent rule, a highlighted panel), read
  the site's brand tokens with a fallback — `color: var(--brand-primary, #22443B)` — using the
  values from `get_design_context()` as those fallbacks, and never declare a `--brand-…` value
  yourself.
- Prefer reusing an existing page's classes over inventing new inline styling. The safest page
  is one whose HTML looks like the site's other pages.
- When the design's palette and the site's genuinely disagree, the site wins. Say what you
  mapped onto what; changing the site's brand colours is a settings change the owner makes in
  the site admin, not something this connector can do.
- If the design's look cannot be reached inside one page's `body_html` — because it changes the
  header, the footer, the type scale, or how every page is drawn — that is **theme work, not
  page work**. It ships as a theme package through `stage_theme`; see
  [media-and-themes.md](media-and-themes.md). Say which parts you can do as a page and which
  need the theme, rather than approximating a site-wide change with one page's markup.

These same principles — semantic structure, responsive by construction, tokens rather than
hardcoded values — are what a theme package is held to as well. A theme is where `--brand-…`
values get *defined*, which is exactly why a page must never define them.

## Images

Images can be uploaded, when the connection has `media:upload`. Take them in this order —
each step is cheaper and safer than the one below it:

1. **Media already on the site.** Call `list_media()` and reuse what is there, or reuse a real
   URL you read out of an existing page with `get_page`. The logo and the main photographs are
   usually already in the library. Never guess or construct an image path; a guessed path is a
   broken image.
2. **Upload it** with `upload_media({filename, content_base64, alt?, folder?})`, and use the
   `url` from the response exactly as returned. An upload needs no approval — it puts the file
   in the library, not on the live site — but say what you are uploading before you do it, and
   check the size limits first. The full rules, limits and refusal wording are in
   [media-and-themes.md](media-and-themes.md).
3. **Inline SVG** for logos, icons, dividers and small decorative marks — copy the `<svg>`
   into `body_html`, with `aria-hidden="true"` when decorative or a `<title>` when meaningful.
   Keep it small; this is not the route for photographs.
4. **Flag it for the operator** when none of the above works — no `media:upload` scope, the
   file too large, the media library switched off. Leave a clearly-marked placeholder in the
   draft, then list every missing image for the user: what it is, where it belongs on the
   page, and that someone needs to add it in the site admin and paste the address back to you.

**Write the `alt` attribute yourself.** The `alt` passed to `upload_media` is a note in the
library; when the response says `alt_is_advisory: true`, the theme does not print it. Every
meaningful `<img>` in `body_html` carries its own `alt`, and every decorative one carries
`alt=""`.

Do not base64-encode photographs into `body_html`; that is what `upload_media` is for, and an
inlined photograph bloats the page and often does not survive sanitizing. And never describe an
image as uploaded, added, or live when all you did was reference or flag it.

## Metadata

- `meta_title` — the browser tab and search result title. Around 60 characters. Follow the
  site's existing convention (some sites append the business name, some do not); check a real
  page with `get_page` rather than assuming.
- `meta_description` — one plain sentence describing the page for search results, around 155
  characters, unique per page. Written for a person; no keyword stuffing, no clipped fragments.
- `og_image` — only an absolute URL to an image that really exists on this site: one from
  `list_media`, one returned by `upload_media`, or one read off an existing page. If you do
  not have one, leave it out rather than inventing a path.

## Copy

The words are the customer's business, not yours to improve silently.

- Keep real names, prices, hours, addresses, claims and testimonials exactly as given.
- Never invent a fact — a phone number, an opening time, a years-in-business claim, a customer
  quote — to fill a slot the design left empty.
- Flag placeholders (lorem ipsum, "Your headline here", sample names) instead of writing over
  them, and ask.
- If you tighten wording for the web, say which sections you changed so the owner can check.

## Before calling `save_draft`

- Content only: no document shell, no header or footer, no scripts.
- Headings match the site's convention and descend one level at a time.
- No artboard pixel widths, no absolute positioning; layouts wrap on a phone.
- No hardcoded palette or fonts from the artboard; colours follow `get_design_context()`.
- Every image is a URL the connector gave you (`list_media`, `upload_media`, or an existing
  page), inline SVG, or an explicitly flagged placeholder — never a constructed path.
- Every `<img>` carries its own `alt`, empty when decorative.
- Nothing in this page needed a theme change; if it did, you said so instead of faking it.
- `slug` is correct, and you have said whether it creates or replaces a page.
- `meta_title` and `meta_description` are set or deliberately carried across.
- You can state, in two sentences the owner would recognize, what this page changes.

## After calling `save_draft`

`save_draft` returns an `edit_url` — the site admin's editor for that draft. Pass it to the
customer exactly as given; it is the only way to look at the draft, because a draft that has
never been published has no address on the live site. Never construct a preview link of your
own, and never present the live page's address as though it showed the draft.
