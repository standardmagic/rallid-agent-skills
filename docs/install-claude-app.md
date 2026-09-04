# Update your website from the Claude app

You can ask Claude to update your Rallid-hosted website — write a page, redo an existing one,
add an event, upload a photo, or turn a design into a real page — straight from the Claude app
on the web or your desktop.

Setting it up takes about five minutes and three steps. You only do it once.

## What you need

- A Claude account you can sign in to at [claude.ai](https://claude.ai), or the Claude desktop
  app.
- The **connector address**, which is the same for everybody: **connect.rallid.com**. There is
  no private address to hunt for.
- A Rallid-hosted website, and the ability to sign in to its admin — that is where you approve
  anything that goes live. **If you do not have a Rallid account yet, that is fine**: you can
  make one during Step 3, and Claude can set up a trial site for you afterwards.

## Step 1 — download the skill file

From your Rallid hosting portal, download **`publish-rallid-site.zip`**. Save it somewhere you
can find again, such as your Downloads folder. Do not unzip it — Claude wants the zip exactly
as it is.

The skill is the instruction booklet: it teaches Claude how pages on your site are built, how
to turn a design into one, and to never put anything live without asking you first.

*Already installed the Rallid plugin from Claude's directory? Then you have the skill and can
skip Steps 1 and 2 — go straight to Step 3.*

## Step 2 — add the skill to Claude

1. In the Claude app, open **Settings**.
2. Go to **Capabilities → Skills**.
3. Choose **Upload skill** and pick the `publish-rallid-site.zip` file you just downloaded.

"Publish to a Rallid site" now appears in your list of skills. Claude uses it automatically
when you ask about your website — you never have to name it.

## Step 3 — connect your website

1. Still in **Settings**, go to **Connectors**.
2. Choose **Add custom connector**.
3. Enter **connect.rallid.com**, then follow the sign-in prompt and approve access.

The connector is the door to your site. It lets Claude see your pages and save drafts. Your
website password never goes into the chat, and nothing is published without your approval.

### No Rallid account yet?

The sign-in page has a **Create a Rallid account** option. It asks for your email address,
sends you a six-character code to type in, and then sets up a passkey so you do not need a
password at all. When that is done it brings you back to the connection and you carry on here.

All of that happens on Rallid's own page. **Claude never asks you for your email address or
that code in the chat** — if anything in a conversation does, do not type it.

### If you do not have a website yet

Once you are connected, say "set up my site" and Claude will create one for you: a **14-day
trial**, one per account, on the free tier. It will ask you first.

Moving to a paid plan, or adding a second site, happens in the Rallid portal — never inside a
chat.

### Which site?

If your account has more than one site, Claude asks which one you mean before it touches
anything, and remembers your answer for that connection. If you want to switch later, just say
so.

One limit worth knowing: this connector works with sites in Rallid's **staging** environment.
For a site Rallid set up for you, that is your real website — the one your visitors see. A
site running on your own custom domain in production needs its own separate connector instead;
Claude will tell you if that is your situation rather than quietly using a different site.

## Try it

Start a new conversation and say what you want in your own words:

- "Update my website — the About page should mention that we now open on Sundays."
- "Publish this design to my site." (attach the design export)
- "Put this page on my site as a draft so I can look at it."
- "Add our summer fête to the events page — 4 July, 6:30pm, in the church hall."
- "Use this photo on the home page." (attach the photo)

Claude will tell you which site it is connected to, show you what it plans to change, and save
the result as a **draft**. Nothing appears on your live site at that point.

## Looking at the draft

When Claude saves a draft it gives you a link straight into your site's editor for that page.
Open it to read the draft over, change a word, or just see how it looks. A draft has no public
address — it exists only inside your site admin until you publish it — so that link is the way
to see it.

You can also ask Claude to read the draft back to you in the chat.

## Events, photos, and how your site looks

Pages are the everyday thing, but the same connection does three more:

- **Events.** If your site runs the events plugin, you can say "add our summer fête on the
  fourth of July at half six" and Claude will draft the event — title, times, location,
  tickets, speakers — for you to approve like anything else. Times you give without a timezone
  are read as your site's own local time, which is almost always what you meant. One catch: an
  event that is already published has to be set back to **Draft** in your events admin before
  Claude can change it.
- **Photos and files.** Claude can put images into your site's media library and use them on a
  page. It looks at what is already there first, so you do not end up with four copies of your
  logo. Files have to be a reasonable size — under 5 MB each — and there is a cap on how many
  can go up in an hour, so a big photo shoot may need a couple of goes or a hand from you in
  the site admin.
- **How the whole site looks.** A redesign — new header, new footer, new colours everywhere —
  is a *theme*, not a page. Claude can read the theme you are on now, make a change to it
  ("darker footer", "rounder buttons"), and prepare the updated version for you. Switching it
  on changes every page at once, so your approval desk keeps a one-click Revert if you do not
  like it. Preparing the theme changes nothing that visitors can see.

## Putting a page live

When you are happy with the draft, say so — "yes, publish it".

Claude sends a publishing request to your site admin and tells you where to find it: under
**Apps → Agent Publishing → Publication requests**. You sign in, confirm it there, then tell
Claude you have. Claude checks that the confirmation really landed before publishing. Only
then does the page go live.

The same request-and-approve step covers an event and a theme, not just a page. Nothing on
your site changes any other way.

**A full admin has to be the one who approves it** — for a page, an event or a theme alike. If
that is not you, Claude will say the request is waiting on a full admin rather than sending you
looking for a button you will not have.

That extra step is deliberate: your site never changes because of something a chat window
decided on its own. If you turn a request down, or leave it long enough to expire, Claude will
tell you and stop — it will not ask again on its own.

If the draft is changed after you approve it, the site refuses to publish, because what you
approved is no longer what is there. Nothing is lost: ask Claude to send a fresh request, and
approve that one.

## What Claude can and cannot do here

**It can** read your published pages and drafts, see your site's colours and fonts so new
pages match, write and rewrite page content, set the page title and the search-result
description, draft events and other things your site's plugins store, add images to your media
library, prepare a new theme — and, after you confirm in your site admin, publish any of it.

**It cannot** delete anything at all, change your menus or site settings, install plugins,
manage your plan or billing, add a second site, or touch your hosting, domain or server. It
also cannot publish anything on its own: every change waits for a full admin's approval in your
site admin.

Some pages can be set so that **only a full admin** may edit them. Claude cannot see or change
those at all, and will say so rather than working around it.

## Turning it off

You are in charge of the connection. To disconnect it, open your Rallid portal and go to
**Connected apps** — the connection is listed there and you can revoke it in one step. Do that
and Claude immediately loses all access to your site.

## If something is not working

- **Claude says it is not connected to your site.** Re-check Step 3 in Settings → Connectors;
  the connection may have expired and need signing in again.
- **Claude names a different website than yours.** Stop and check which connector is active. It
  is meant to refuse to write to a site you did not ask for.
- **Claude cannot publish, only draft.** Your connection was set up for drafts only. The draft
  is saved and someone with publishing rights can publish it from your site admin.
- **Claude says the page is admin-only.** That page is restricted to full admins; a full admin
  can change it in your site admin.
- **Claude says your approval has not come through.** Open the link it gave you, confirm the
  request there, then tell Claude to check again. Approvals expire after a short while — if
  yours did, just ask Claude to send a fresh one.
- **Claude says it cannot change an event.** The event is already published. Set it back to
  **Draft** in your events admin, and Claude can pick it up again.
- **A photo will not upload.** Usually the file is too big or is a format the site does not
  take. Claude will say which, and can shrink or convert it — or you can add the original in
  your site admin under **Media** and give Claude the address.
- **The theme was turned down.** Your site checks a theme before accepting it. Claude will show
  you exactly what it flagged and fix it. Nothing on your site changed.
- **Something went wrong on the site's side.** Claude will show you a reference code that
  starts with `err_`. Send that to Rallid support — it points them straight at what happened.
- **Anything asks you for an API key or password in the chat.** Do not paste it. Claude never
  needs one here — the connector handles signing in. The same goes for your Rallid sign-up code:
  that belongs on Rallid's sign-in page, never in a conversation.

---

*Building the file yourself: from a checkout of this repository, run
`node scripts/build-claude-ai-zip.mjs`, which writes `dist/publish-rallid-site.zip`.*
