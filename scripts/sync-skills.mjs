#!/usr/bin/env node

import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, "..");
const sourceDirectory = resolve(repositoryRoot, "skills");

// The helper-driven CLI skills. They need a shell and a scoped BlackRail token, so
// they ship only where a shell exists, and only they get the helper-location note.
const cliSkills = ["connect-rallid-site", "publish-blackrail-pages"];

// The connector-driven consumer skill. It must never mention a shell, a helper or a
// token, because it runs in chat against the Rallid MCP connector.
const connectorSkill = "publish-rallid-site";

// Each surface packages only the skills it can actually run.
//   claude    — the Claude plugin, installed from Claude's unified directory. It reaches
//               both Claude Code (where the CLI skills run) and chat on claude.ai and the
//               desktop app (where the connector skill runs), so it ships all three.
//   codex     — Codex has no Rallid connector, so the connector skill would be dead weight
//               that advertises tools the surface cannot provide. CLI skills only.
//   claude-ai — the standalone zip a customer uploads at Settings > Capabilities > Skills.
//               Exactly one skill folder, and it must be the connector one.
const targets = [
  {
    provider: "claude",
    directory: resolve(repositoryRoot, "providers/claude/plugin/skills"),
    skills: [...cliSkills, connectorSkill],
  },
  {
    provider: "codex",
    directory: resolve(repositoryRoot, "providers/codex/plugin/skills"),
    skills: [...cliSkills],
  },
  {
    provider: "claude-ai",
    directory: resolve(repositoryRoot, "providers/claude-ai/skill"),
    skills: [connectorSkill],
  },
];

const claudeHelperReference = `# Resolve the helper path

Claude Code exposes the installed plugin root as \`CLAUDE_PLUGIN_ROOT\`. Set:

\`\`\`bash
BLACKRAIL_PAGES_HELPER="\${CLAUDE_PLUGIN_ROOT}/skills/publish-blackrail-pages/scripts/blackrail-pages.sh"
\`\`\`

Keep the expansion quoted when invoking \`"$BLACKRAIL_PAGES_HELPER"\`. Do not derive the helper path from \`pwd\` or the user's current working directory.
`;

if (!existsSync(sourceDirectory)) {
  console.error(`Source skills not found: ${sourceDirectory}`);
  process.exit(1);
}

const sourceSkills = readdirSync(sourceDirectory, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name);

const packagedSkills = new Set(targets.flatMap((target) => target.skills));

for (const skill of sourceSkills) {
  if (!packagedSkills.has(skill)) {
    console.error(`Source skill is not packaged by any provider: ${skill}`);
    process.exit(1);
  }
}

for (const skill of packagedSkills) {
  if (!sourceSkills.includes(skill)) {
    console.error(`Provider references a missing source skill: ${skill}`);
    process.exit(1);
  }
}

for (const target of targets) {
  rmSync(target.directory, { recursive: true, force: true });
  mkdirSync(target.directory, { recursive: true });

  for (const skill of target.skills) {
    cpSync(resolve(sourceDirectory, skill), resolve(target.directory, skill), {
      recursive: true,
    });
  }

  // Only the helper-driven CLI skills get the Claude Code helper-path note. Writing it
  // into the connector skill would put a shell workflow inside a chat-only skill.
  if (target.provider === "claude") {
    for (const skill of target.skills) {
      if (!cliSkills.includes(skill)) continue;
      writeFileSync(
        resolve(target.directory, skill, "references/helper-location.md"),
        claudeHelperReference,
      );
    }
  }

  console.log(
    `Synced ${target.skills.length} skills to ${target.directory.replace(`${repositoryRoot}/`, "")}`,
  );
}
