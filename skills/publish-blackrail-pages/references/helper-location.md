# Resolve the helper path

Codex provides the absolute path of a selected skill's `SKILL.md`. Starting from the absolute directory that contains this `publish-blackrail-pages/SKILL.md`, resolve:

```text
scripts/blackrail-pages.sh
```

Assign that resolved absolute path to `BLACKRAIL_PAGES_HELPER`. Do not derive it from `pwd`, the repository root, or the user's current working directory.
