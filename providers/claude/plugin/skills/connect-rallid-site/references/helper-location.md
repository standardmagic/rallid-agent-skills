# Resolve the helper path

Claude Code exposes the installed plugin root as `CLAUDE_PLUGIN_ROOT`. Set:

```bash
BLACKRAIL_PAGES_HELPER="${CLAUDE_PLUGIN_ROOT}/skills/publish-blackrail-pages/scripts/blackrail-pages.sh"
```

Keep the expansion quoted when invoking `"$BLACKRAIL_PAGES_HELPER"`. Do not derive the helper path from `pwd` or the user's current working directory.
