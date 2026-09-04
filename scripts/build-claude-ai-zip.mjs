#!/usr/bin/env node

// Builds the claude.ai skill upload: dist/publish-rallid-site.zip, with the skill
// folder at the ZIP root (publish-rallid-site/SKILL.md, publish-rallid-site/references/…).
// That is the layout Settings > Capabilities > Skills > Upload skill expects.
//
// Zero dependencies. Uses the system `zip` for the archive itself.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, rmSync, statSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, "..");
const skillName = "publish-rallid-site";
const providerDirectory = resolve(repositoryRoot, "providers/claude-ai/skill");
const skillDirectory = resolve(providerDirectory, skillName);
const distDirectory = resolve(repositoryRoot, "dist");
const archivePath = resolve(distDirectory, `${skillName}.zip`);

function fail(message) {
  console.error(message);
  process.exit(1);
}

function run(command, args, options = {}) {
  return execFileSync(command, args, { encoding: "utf8", ...options });
}

try {
  run("zip", ["-v"], { stdio: "ignore" });
} catch {
  fail("The system `zip` command is required to build the claude.ai skill archive.");
}

// Always package what the source skill currently says.
run("node", [resolve(repositoryRoot, "scripts/sync-skills.mjs")], { stdio: "inherit" });

if (!existsSync(resolve(skillDirectory, "SKILL.md"))) {
  fail(`Missing skill entry point: ${relative(repositoryRoot, resolve(skillDirectory, "SKILL.md"))}`);
}

function collect(directory) {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const absolute = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...collect(absolute));
    } else if (entry.isFile()) {
      files.push(absolute);
    }
  }
  return files.sort();
}

const files = collect(skillDirectory);

mkdirSync(distDirectory, { recursive: true });
rmSync(archivePath, { force: true });

run(
  "zip",
  [
    "--quiet",
    "--recurse-paths",
    "-X", // no extra platform attributes, so the archive stays reproducible
    archivePath,
    skillName,
    "--exclude",
    "*/.DS_Store",
    "*/__MACOSX/*",
  ],
  { cwd: providerDirectory },
);

if (!existsSync(archivePath)) {
  fail("The archive was not produced.");
}

let entries = files.map((file) => `${skillName}/${relative(skillDirectory, file)}`);
try {
  entries = run("unzip", ["-Z1", archivePath])
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .sort();
} catch {
  // `unzip` is optional; fall back to the file list that was handed to `zip`.
}

for (const entry of entries) {
  if (!entry.startsWith(`${skillName}/`)) {
    fail(`Archive entry is not inside the skill folder: ${entry}`);
  }
}

if (!entries.includes(`${skillName}/SKILL.md`)) {
  fail(`Archive does not contain ${skillName}/SKILL.md at the ZIP root.`);
}

const sizeInKilobytes = (statSync(archivePath).size / 1024).toFixed(1);
console.log(`Built ${relative(repositoryRoot, archivePath)} (${sizeInKilobytes} KB)`);
for (const entry of entries) {
  console.log(`  ${entry}`);
}
