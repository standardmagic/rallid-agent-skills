# Plugin resources: events, and whatever else the site runs

A Rallid site is a page CMS plus whatever plugins the owner has switched on. Those plugins
store their own content — events today, more later — and the connector reaches all of it
through **one generic set of tools**, not a tool per plugin.

That is why nothing here is named `create_event`. The site tells you what it has; you read
that and work from it.

## The four tools

| Tool | What it does |
| --- | --- |
| `list_resources()` | Read-only. Every resource this site exposes: `key`, `label`, a JSON schema, and `record_tools` naming the tool that writes it |
| `list_records({resource, cursor?, limit?})` | A page of summary rows for one resource, plus a cursor |
| `get_record({resource, id})` | One record in full: `{resource, id, record, edit_url}` |
| `save_record_draft({resource, id?, record})` | Creates (`id` omitted) or **patches** (`id` given) one record, as a **draft**. Returns the same `{resource, id, record, edit_url}` shape |

`list_resources` and the two readers need `resources:read`. `save_record_draft` needs
`resources:edit`, and so does requesting publication of a record.

**All four refuse `resource: "page"`.** Pages have their own tools — `list_pages`, `get_page`,
`get_draft`, `save_draft` — and a page is not a record. If you find yourself reaching for
`save_record_draft` on a page, you are in the wrong playbook.

**`theme` is a resource, with a different writer.** `list_records({resource: 'theme'})` and
`get_record({resource: 'theme', id})` work exactly as they do for events, but the theme
resource's `record_tools.save_draft` names **`stage_theme`**, not `save_record_draft`. That is
precisely what `record_tools` is for: read the resource generically, write it with the tool
the site names. Never assume the writer — read it off `list_resources()`. The theme build
contract is in [theme-package.md](theme-package.md).

## The flow

1. **`list_resources()` first, in every session that touches plugin content.** Do not assume a
   site has events, or that its events resource has the fields you remember. A resource that
   is not in the list does not exist on this site, and saying so plainly is the right answer —
   not offering to build the same thing out of pages.
2. **Read the schema it returns and treat it as the contract.** It is the authority on field
   names, which are required, and what a value may be. Anything below in this file is
   orientation for the conversation; the schema is what the server enforces.
3. **`list_records({resource})` to see what is already there.** Rows are a *summary*. Do not
   describe a record's content, or claim to know what it says, from a row alone.
4. **`get_record({resource, id})` before you change anything.** Same reason you read a page
   before rewriting it: to know what is there, and to be able to say what will change.
5. **Show the user what you are about to save, in their words**, then
   **`save_record_draft({resource, id?, record})`**.
6. **Publication is the ordinary five-status flow** — `request_publish({resource, id,
   change_summary})`, the owner's confirmation in the site admin, `get_approval`, `publish`.
   Nothing about a record shortens it.

## `save_record_draft` is a patch, not a replacement

This is the single detail that most often goes wrong, and it goes wrong in the direction of
destroying data, so read it twice.

**With an `id`, you are sending a patch.** The server fetches the stored record itself, merges
the fields you sent onto it, validates the merged result against the schema, and saves that.

- **Omit a field to leave it exactly as it is.** You do not need to resend `start_at` to change
  a `title`.
- **Send an empty value to clear a field.** That is the only way to empty one, and it is a
  deliberate act — do not send `""` for a field you simply did not have to hand.
- **Never resend a record from memory.** A record you are holding from earlier in the
  conversation, or one you reconstructed from a list row, is a stale copy: sending it back
  overwrites every field with what you *think* is there, silently undoing anything changed in
  the admin since. Send the change, not the record.

So, to change one field on an existing record:

1. `get_record({resource, id})` — to see what is there and to be able to describe the change.
2. `save_record_draft({resource, id, record: { theField: newValue }})` — that field alone.

**Without an `id`, you are creating**, and there is no stored record to merge onto, so every
field the schema marks `required` must be present in what you send.

An `id` that does not exist comes back **`not_found`**, before the plugin's own code runs at
all. That is a wrong id, not a permissions problem and not a broken record: check the id
against `list_records` rather than retrying or creating a duplicate.

Both calls return `{resource, id, record, edit_url}`. **`edit_url` is the admin editor link
for that record — hand it to the owner after every draft**, exactly as returned, the same way
you would a page's. It is how they look at what you wrote.

## Refusals: three kinds you relay, one kind you escalate

A refusal from a record tool is usually written by the plugin, for the site owner, and it
names the exact thing to do next in that plugin's admin.

**Three kinds reach you as the words that were written, and all three are relayed as-is:**

1. A **plugin's own refusal** — the plugin declining the operation on purpose (a published
   event, a state that forbids the edit).
2. A **validation error from the plugin's own checks** — the record was wrong in a way the
   plugin, not the schema, decides.
3. A **runtime error the plugin raised deliberately** — something it could not do, explained.

For all three: **relay the message verbatim.** Add context around it if that helps — where the
events admin lives, what you will do once they have done their part — but do not summarize it,
soften it, or translate it into your own words. If you paraphrase, the instruction it carries
is what gets lost. Then stop: no retry of the same call, no different tool, and no routing
around it by creating a second record.

**Everything else arrives as `internal_error`**, and it is not written for the owner. It
carries a reference of the form **`err_1a2b3c4d5e6f`**. Say plainly that something went wrong
on the site's side, give the customer that reference, and tell them to quote it to Rallid
support. **Never retry blindly on an `internal_error`** — you do not know whether the first
call took effect, and a blind retry is how one event becomes two.

## The `events` resource

The first real resource. Key: `events`.

`list_resources()` returns the authoritative schema. This is what to expect:

| Field | Notes |
| --- | --- |
| `title` | **Required on create.** The event's name |
| `summary` | A sentence or two; listings use it |
| `body_html` | The event's own content. Same rules as a page's `body_html` — see [content-contract.md](content-contract.md) |
| `location` | Where it happens, as the owner would write it |
| `start_at` | **Required on create.** See timestamps below |
| `end_at` | Same format as `start_at` |
| `image_url` | An address that really exists: from `list_media`, from an `upload_media` response, or read off an existing record. Never construct one |
| `ticket_url` | Where to buy or register |
| `ticket_cost` | As the owner says it. Do not normalize their wording or invent a currency |
| `speakers` | A list of `{name, role}` entries |
| `is_postponed` | The postponed flag |

"Required on create" is exactly what it says: the schema's required fields must all be in a
create. An **update is a patch**, so a required field you are not changing is simply left out
and the stored value survives.

**The schema is closed to unknown fields.** An extra key you invented — `subtitle`, `tags`,
`price` — is a validation failure, not an ignored extra. If the owner wants something the
schema has no room for, the honest answer is that the events plugin does not store it, and it
may belong in `body_html` instead.

Publishing an event is the ordinary approval flow, and `publish_permission` on the request
names the capability the plugin declared for it — `content.publish`. `approver` is
`full_admin`, as it is for every resource.

### Timestamps

Three shapes, and the difference matters:

- **`2026-07-04T18:30`** — no offset. This means **the site's own local time**: half past six
  in the evening where the event is. This is what you want almost every time, because it is
  how the owner said it.
- **`2026-07-04T18:30:00Z`, or with an offset like `2026-07-04T18:30:00+01:00`** — this names
  an exact instant, and the site converts it to its own timezone on the way in. Use it only
  when the user genuinely gave you a UTC time or a time in another zone.
- **`2026-07-04`** — a date with no time at all means an **all-day** event.

Never guess an offset to look precise. If the owner says "Saturday the fourth at 6:30", write
`2026-07-04T18:30` and let the site's timezone do its job. If they gave a time in a different
city, say what you are converting from before you write an offset.

### A published event cannot be edited

The tools refuse it, and the refusal tells the owner what to do: set the event back to
**Draft** in the events admin, at which point you can change it and take it through the
approval flow again.

That is the plugin's own refusal, so relay it verbatim, add nothing but where to find it, and
stop. Do not create a second event with the corrected details — the site would then have two,
and the wrong one is the one visitors can see.

### List rows are thin

`list_records({resource: 'events'})` returns rows of `{id, title, status, start_at}` and
nothing else. That is enough to find an event and to say how many there are; it is not enough
to describe one. Call `get_record` before you summarize an event's contents, quote its
description, or edit it.

### The event *page* is not a record

How an event renders — the layout of its page, the listing, the styling of the date and the
ticket button — belongs to the **theme**, not to any field on the record. A request to "change
how our events look" is theme work; see [media-and-themes.md](media-and-themes.md). Do not try
to reach it by stuffing layout markup into `body_html`: it would apply to one event, and the
next one the owner adds by hand would not match.

## Before you save a record

- You called `list_resources()` in this session and read the schema you are writing against.
- For an update: you are sending only the fields you are changing, and none of them came from
  memory. For a create: every required field in the schema is present.
- No invented field names; the schema is closed.
- Timestamps are in the shape you meant — local time unless you deliberately named an instant.
- Every URL in the record is one you actually read from the connector.
- Real names, dates, prices and quotes are exactly as the owner gave them, and anything you
  had to fill in is flagged rather than guessed.
- You can say in two sentences what this record change does, in words the owner would use.
