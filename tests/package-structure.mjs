#!/usr/bin/env node

import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const testDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(testDirectory, "..");
const read = (relativePath) => readFileSync(resolve(repositoryRoot, relativePath), "utf8");
const listFiles = (relativePath) => {
  const root = resolve(repositoryRoot, relativePath);
  const walk = (directory) =>
    readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
      const absolute = join(directory, entry.name);
      if (entry.isDirectory()) return walk(absolute);
      return entry.isFile() ? [relative(root, absolute)] : [];
    });
  return walk(root).sort();
};

const codexManifest = JSON.parse(
  read("providers/codex/plugin/.codex-plugin/plugin.json"),
);
const defaultPrompts = codexManifest.interface?.defaultPrompt;
assert.ok(Array.isArray(defaultPrompts), "Codex defaultPrompt must be an array");
assert.ok(defaultPrompts.length > 0, "Codex defaultPrompt must not be empty");
for (const prompt of defaultPrompts) {
  assert.equal(typeof prompt, "string", "Each Codex default prompt must be a string");
  assert.ok(
    Array.from(prompt).length <= 128,
    `Codex default prompt exceeds 128 characters: ${prompt}`,
  );
}

for (const manifest of [
  ".agents/plugins/marketplace.json",
  ".claude-plugin/marketplace.json",
  "providers/claude/plugin/.claude-plugin/plugin.json",
]) {
  JSON.parse(read(manifest));
}

const sharedGeneratedFiles = [
  "connect-rallid-site/SKILL.md",
  "connect-rallid-site/agents/openai.yaml",
  "connect-rallid-site/references/access-model.md",
  "publish-blackrail-pages/SKILL.md",
  "publish-blackrail-pages/agents/openai.yaml",
  "publish-blackrail-pages/references/page-api.md",
  "publish-blackrail-pages/scripts/blackrail-pages.sh",
];

for (const relativePath of sharedGeneratedFiles) {
  const source = read(`skills/${relativePath}`);
  assert.equal(
    read(`providers/codex/plugin/skills/${relativePath}`),
    source,
    `Codex generated copy is stale: ${relativePath}`,
  );
  assert.equal(
    read(`providers/claude/plugin/skills/${relativePath}`),
    source,
    `Claude generated copy is stale: ${relativePath}`,
  );
}

for (const skill of ["connect-rallid-site", "publish-blackrail-pages"]) {
  const sourceReference = read(`skills/${skill}/references/helper-location.md`);
  const codexReference = read(
    `providers/codex/plugin/skills/${skill}/references/helper-location.md`,
  );
  const claudeReference = read(
    `providers/claude/plugin/skills/${skill}/references/helper-location.md`,
  );

  assert.equal(codexReference, sourceReference, `Codex helper reference is stale: ${skill}`);
  assert.match(
    codexReference,
    /absolute path of a selected skill's `SKILL\.md`/,
    `Codex helper path is not anchored to the installed skill resource: ${skill}`,
  );
  assert.ok(
    claudeReference.includes("${CLAUDE_PLUGIN_ROOT}/skills/publish-blackrail-pages/scripts/blackrail-pages.sh"),
    `Claude helper path does not use CLAUDE_PLUGIN_ROOT: ${skill}`,
  );
}

const canonicalInstructions = [
  read("skills/connect-rallid-site/SKILL.md"),
  read("skills/publish-blackrail-pages/SKILL.md"),
].join("\n");
assert.ok(
  !canonicalInstructions.includes("BLACKRAIL_PRODUCTION_APPROVED"),
  "Obsolete boolean-only production approval remains in skill instructions",
);

// The claude.ai upload ships exactly one skill, byte-identical to its source.
const claudeAiSkill = "publish-rallid-site";

// Every source skill needs parsable frontmatter whose name matches its directory.
// The claude.ai upload additionally enforces that surface's length limits.
const sourceSkills = readdirSync(resolve(repositoryRoot, "skills"), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();

for (const skill of sourceSkills) {
  const skillDocument = read(`skills/${skill}/SKILL.md`);
  const frontmatter = skillDocument.match(/^---\n([\s\S]*?)\n---\n/);
  assert.ok(frontmatter, `SKILL.md has no YAML frontmatter: ${skill}`);

  const fields = new Map();
  for (const line of frontmatter[1].split("\n")) {
    const separator = line.indexOf(":");
    assert.ok(separator > 0, `Unparsable frontmatter line in ${skill}: ${line}`);
    fields.set(line.slice(0, separator).trim(), line.slice(separator + 1).trim());
  }

  const name = fields.get("name");
  const description = fields.get("description");
  assert.equal(name, skill, `Frontmatter name must match the skill directory: ${skill}`);
  assert.ok(description, `Skill description is missing: ${skill}`);

  if (skill === claudeAiSkill) {
    assert.ok(
      Array.from(name).length <= 64,
      `claude.ai skill name exceeds 64 characters (${Array.from(name).length}): ${skill}`,
    );
    assert.ok(
      Array.from(description).length <= 200,
      `claude.ai skill description exceeds 200 characters (${Array.from(description).length}): ${skill}`,
    );
  }
}

const claudeAiRoot = `providers/claude-ai/skill/${claudeAiSkill}`;
const claudeAiSourceFiles = listFiles(`skills/${claudeAiSkill}`);
assert.deepEqual(
  listFiles(claudeAiRoot),
  claudeAiSourceFiles,
  "claude.ai provider file list does not match the source skill",
);
assert.ok(
  claudeAiSourceFiles.includes("SKILL.md"),
  "claude.ai skill is missing SKILL.md at its root",
);
for (const relativePath of claudeAiSourceFiles) {
  assert.equal(
    read(`${claudeAiRoot}/${relativePath}`),
    read(`skills/${claudeAiSkill}/${relativePath}`),
    `claude.ai generated copy is stale: ${relativePath}`,
  );
}
assert.deepEqual(
  readdirSync(resolve(repositoryRoot, "providers/claude-ai/skill"), { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name),
  [claudeAiSkill],
  "The claude.ai upload must contain exactly one skill folder",
);

// The connector skill ships in the Claude plugin, and never in the Codex plugin.
//
// Why the asymmetry: the Claude plugin is what Claude's unified directory installs, and that
// install reaches chat on claude.ai and the desktop app as well as Claude Code — chat is
// exactly where the Rallid connector's tools live, so the connector skill belongs there. It is
// still chat-only in substance: it must arrive without the helper-location note the CLI skills
// get, and the shell-workflow assertions below still apply to it byte for byte. Codex has no
// Rallid connector at all, so shipping it there would advertise tools the surface cannot
// provide. (An earlier revision asserted the connector skill never shipped in *either* CLI
// plugin; that predates the unified directory.)
const claudePluginConnectorRoot = `providers/claude/plugin/skills/${claudeAiSkill}`;
assert.ok(
  existsSync(resolve(repositoryRoot, claudePluginConnectorRoot)),
  "The connector skill must ship inside the Claude plugin for the unified directory",
);
assert.deepEqual(
  listFiles(claudePluginConnectorRoot),
  claudeAiSourceFiles,
  "Claude plugin copy of the connector skill does not match the source skill",
);
for (const relativePath of claudeAiSourceFiles) {
  assert.equal(
    read(`${claudePluginConnectorRoot}/${relativePath}`),
    read(`skills/${claudeAiSkill}/${relativePath}`),
    `Claude plugin copy of the connector skill is stale: ${relativePath}`,
  );
}
assert.ok(
  !existsSync(
    resolve(repositoryRoot, `${claudePluginConnectorRoot}/references/helper-location.md`),
  ),
  "The connector skill must not receive the CLI helper-location note in the Claude plugin",
);
assert.ok(
  !existsSync(resolve(repositoryRoot, `providers/codex/plugin/skills/${claudeAiSkill}`)),
  "The connector skill must not ship inside the Codex plugin: Codex has no Rallid connector",
);

const connectorSkillText = claudeAiSourceFiles
  .map((relativePath) => read(`skills/${claudeAiSkill}/${relativePath}`))
  .join("\n");
for (const forbidden of [
  "```bash",
  "```sh",
  "```shell",
  "BLACKRAIL_PAGES_HELPER",
  "BLACKRAIL_API_TOKEN",
  "blackrail-pages.sh",
  "CLAUDE_PLUGIN_ROOT",
]) {
  assert.ok(
    !connectorSkillText.includes(forbidden),
    `The claude.ai skill must not reference a shell workflow: ${forbidden}`,
  );
}

// Every tool the gateway and the engine expose. A name that drifts here is a name the skill
// would call and the server would not answer, so each one is pinned literally.
for (const tool of [
  // gateway
  "list_sites",
  "select_site",
  "create_site",
  // pages
  "check_connection",
  "get_design_context",
  "list_pages",
  "get_page",
  "get_draft",
  "save_draft",
  // generic plugin resources
  "list_resources",
  "list_records",
  "get_record",
  "save_record_draft",
  // media
  "list_media",
  "upload_media",
  // themes
  "stage_theme",
  "list_theme_files",
  "get_theme_file",
  // publication
  "request_publish",
  "get_approval",
  "publish(",
]) {
  assert.ok(
    connectorSkillText.includes(tool),
    `The claude.ai skill does not document the connector tool: ${tool}`,
  );
}

// Every scope name preflighted from check_connection().scopes.
for (const scope of [
  "pages:read",
  "pages:edit",
  "resources:read",
  "resources:edit",
  "media:upload",
  "themes:stage",
]) {
  assert.ok(
    connectorSkillText.includes(scope),
    `The claude.ai skill does not cover the scope: ${scope}`,
  );
}

// Publication is approval-only: no scope grants it, and no *:publish scope exists to look for.
assert.ok(
  !/\b(pages|resources|media|themes):publish\b/.test(connectorSkillText),
  "The claude.ai skill must not imply a publishing scope exists",
);

// Refusal error codes the skill has to branch on.
for (const errorCode of [
  "unsupported_media",
  "invalid_filename",
  "too_large",
  "rate_limited",
  "permission_denied",
  "missing_scope",
  "feature_disabled",
  "theme_invalid",
  "digest_mismatch",
  "not_found",
  "internal_error",
]) {
  assert.ok(
    connectorSkillText.includes(errorCode),
    `The claude.ai skill does not handle the refusal error code: ${errorCode}`,
  );
}

// v1 contract details the workflow depends on.
for (const contractDetail of [
  "admin_url",
  "edit_url",
  "approval_id",
  "payload_sha256",
  "instructions",
  "Agent Publishing",
  "next_step",
  "zip_base64",
  "content_base64",
  "alt_is_advisory",
  "record_tools",
  "approver",
  "full_admin",
  "publish_permission",
  "content.publish",
  "err_1a2b3c4d5e6f",
  "alt_is_advisory",
  "Connected apps",
  "14-day",
  "six-character",
  "environment",
  "staging",
  "pending",
  "approved",
  "declined",
  "consumed",
  "expired",
]) {
  assert.ok(
    connectorSkillText.includes(contractDetail),
    `The claude.ai skill does not cover the connector contract detail: ${contractDetail}`,
  );
}

// The events resource schema is closed, so every field name has to be exactly right.
for (const eventField of [
  "start_at",
  "end_at",
  "ticket_url",
  "ticket_cost",
  "is_postponed",
  "speakers",
  "image_url",
  "body_html",
]) {
  assert.ok(
    connectorSkillText.includes(eventField),
    `The claude.ai skill does not document the events schema field: ${eventField}`,
  );
}

// The theme package contract: a model has to be able to build a zip stage_theme accepts,
// so the file names, manifest fields, slot rules and zip layout are pinned literally.
for (const packageRule of [
  "theme.json",
  "assets/theme.css",
  "custom-page.html",
  "form-page.html",
  "not-found.html",
  "protected-page.html",
  "form-verification.html",
  "site-header.html",
  "site-footer.html",
  "comp-site-header",
  "comp-site-footer",
  "data-component-root",
  '"type": "declarative"',
  "pageRootAttr",
  "headMeta",
  "brandCss",
  "inlineEditorAssets",
  "formDataAttrs",
  "poweredByFooter",
  "MANIFEST.sha256",
  "/blackrail-theme-assets/assets/",
  "brand_[a-z_]+",
  "3000",
  "1 MiB",
  "SITE_NAME",
  "CONTACT_CTA",
]) {
  assert.ok(
    connectorSkillText.includes(packageRule),
    `The claude.ai skill does not pin the theme package rule: ${packageRule}`,
  );
}

// A declarative theme carries no code, and the skill must never define a brand token.
assert.ok(
  /never declare a `--brand-\*`/i.test(connectorSkillText),
  "The claude.ai skill does not forbid declaring a --brand-* value in a theme",
);
assert.ok(
  /no\s+`?\.php`?,?\s+`?\.js`?/i.test(connectorSkillText),
  "The claude.ai skill does not state that a declarative theme carries no PHP or JavaScript",
);

// `theme` is a real resource: readable generically, written by stage_theme via record_tools.
assert.ok(
  connectorSkillText.includes("resource: 'theme'"),
  "The claude.ai skill does not read the theme resource with the generic record readers",
);
assert.ok(
  /`?record_tools\.save_draft`?\s+(set to|names)\s+\*{0,2}`?stage_theme/i.test(connectorSkillText),
  "The claude.ai skill does not map the theme resource's writer to stage_theme",
);

// Theme readback shipped as list_theme_files / get_theme_file — never as export_theme, which
// was only ever a placeholder in an earlier revision of this skill.
assert.ok(
  !connectorSkillText.includes("export_theme"),
  "The claude.ai skill still refers to export_theme, which was never shipped",
);
assert.ok(
  /list_theme_files\(\{\s*id\s*\}\)/.test(connectorSkillText),
  "The claude.ai skill does not document list_theme_files({id})",
);
assert.ok(
  /get_theme_file\(\{\s*id,\s*path\s*\}\)/.test(connectorSkillText),
  "The claude.ai skill does not document get_theme_file({id, path})",
);
assert.ok(
  connectorSkillText.includes("512 KB"),
  "The claude.ai skill does not pin the get_theme_file size ceiling",
);
// An edited theme is a new unsigned version: the old seal must never be repackaged.
assert.ok(
  connectorSkillText.includes("SIGNATURE"),
  "The claude.ai skill does not forbid shipping a SIGNATURE file",
);
assert.ok(
  /new,? unsigned version/i.test(connectorSkillText),
  "The claude.ai skill does not state that an edited signed theme is a new unsigned version",
);

// stage_theme's real ceiling is the MCP request body, not the admin uploader's 40 MB.
assert.ok(
  connectorSkillText.includes("8 MB"),
  "The claude.ai skill does not state the 8 MB stage_theme zip ceiling",
);
assert.ok(
  connectorSkillText.includes("12 MB"),
  "The claude.ai skill does not explain the 12 MB request-body ceiling behind it",
);

// list_media rows carry no alt column, so assets are matched by filename and folder.
for (const mediaRowField of [
  "filename",
  "mime",
  "kind",
  "bytes",
  "folder",
  "managed",
  "usage",
]) {
  assert.ok(
    connectorSkillText.includes(mediaRowField),
    `The claude.ai skill does not document the list_media row field: ${mediaRowField}`,
  );
}
assert.ok(
  /no\s+`?alt`?\s+on a row/i.test(connectorSkillText),
  "The claude.ai skill does not state that list_media rows carry no alt",
);

// Boundaries between the page tools and the record tools, and the whole-record save rule.
assert.ok(
  connectorSkillText.includes('resource: "page"'),
  "The claude.ai skill does not state that the record tools refuse resource: \"page\"",
);
// An update is a PATCH the server merges onto the stored record. The earlier revision of this
// file asserted the opposite ("whole record, every required field resent"); the engine
// hardening replaced replace-semantics with merge-semantics, and resending a remembered record
// now silently overwrites fields, so the wrong instruction is worse than a missing one.
assert.ok(
  !/whole record is validated|resend all required fields|partial diff is rejected/i.test(
    connectorSkillText,
  ),
  "The claude.ai skill still describes save_record_draft as a whole-record replace",
);
assert.ok(
  /\bpatch(es|ing)?\b/i.test(connectorSkillText),
  "The claude.ai skill does not describe save_record_draft as a patch",
);
assert.ok(
  /never resend a record from memory/i.test(connectorSkillText),
  "The claude.ai skill does not forbid resending a record from memory",
);
assert.ok(
  /omit a field to leave it/i.test(connectorSkillText),
  "The claude.ai skill does not explain omit-to-keep / empty-to-clear patch semantics",
);
assert.ok(
  connectorSkillText.includes("{resource, id, record, edit_url}"),
  "The claude.ai skill does not pin the record tools' return shape",
);
// A full admin approves EVERY resource, not only a theme: `approver` is always "full_admin".
assert.ok(
  /a full admin approves (this|every|it)/i.test(connectorSkillText),
  "The claude.ai skill does not state that a full admin approves every resource",
);
assert.ok(
  /always\s+`?full_admin`?/i.test(connectorSkillText),
  "The claude.ai skill does not pin approver to full_admin",
);
assert.ok(
  connectorSkillText.includes("one-click Revert"),
  "The claude.ai skill does not mention the approval desk's one-click theme revert",
);
assert.ok(
  /never ask for an email address or a verification code/i.test(connectorSkillText),
  "The claude.ai skill does not forbid collecting sign-up email or codes in the chat",
);

// The server's stale-digest refusal is relayed verbatim, not paraphrased.
assert.ok(
  connectorSkillText.includes(
    "The draft changed after it was approved, so the approval is void",
  ),
  "The claude.ai skill does not carry the server's stale-digest refusal text",
);

// Publication has no bypass, and drafts have no public address.
assert.ok(
  !/preview[_ -]url/i.test(connectorSkillText),
  "The claude.ai skill must not promise a public draft preview URL",
);

// Links are never invented: they come from the tools, or they do not exist. The one address
// the skill is allowed to state from memory is the connector hostname itself.
assert.ok(
  connectorSkillText.includes("Never invent a link"),
  "The claude.ai skill does not carry the never-invent-a-link rule",
);
assert.ok(
  /never (guess or )?construct(ed)? (an |a )?(image|media) (path|url)/i.test(connectorSkillText),
  "The claude.ai skill does not forbid constructing a media path",
);

// One connector address for everyone, and nothing invented beyond that hostname.
const connectorHostname = "connect.rallid.com";
assert.ok(
  connectorSkillText.includes(connectorHostname),
  "The claude.ai skill does not name the single connector address",
);
const inventedConnectorUrl = new RegExp(
  `${connectorHostname.replace(/\./g, "\\.")}[/:?#]`,
  "i",
);
for (const [label, text] of [
  ["the claude.ai skill", connectorSkillText],
  ["docs/install-claude-app.md", read("docs/install-claude-app.md")],
  ["docs/capability-matrix.md", read("docs/capability-matrix.md")],
  ["README.md", read("README.md")],
]) {
  assert.ok(
    !inventedConnectorUrl.test(text),
    `${label} invents a URL beyond the ${connectorHostname} hostname`,
  );
}

// The customer-facing docs describe the same surface the skill implements.
const installDocument = read("docs/install-claude-app.md");
for (const installDetail of [
  connectorHostname,
  "Create a Rallid account",
  "Connected apps",
  "Add custom connector",
]) {
  assert.ok(
    installDocument.includes(installDetail),
    `docs/install-claude-app.md does not cover: ${installDetail}`,
  );
}

const capabilityMatrix = read("docs/capability-matrix.md");
for (const capabilityDetail of [
  "list_sites",
  "select_site",
  "create_site",
  "list_resources",
  "save_record_draft",
  "upload_media",
  "stage_theme",
  "resources:read",
  "resources:edit",
  "media:upload",
  "themes:stage",
]) {
  assert.ok(
    capabilityMatrix.includes(capabilityDetail),
    `docs/capability-matrix.md does not cover: ${capabilityDetail}`,
  );
}

printfSuccess();

function printfSuccess() {
  process.stdout.write("Package structure tests passed.\n");
}
