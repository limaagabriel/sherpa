#!/usr/bin/env bash
# Sherpa SessionStart hook: delegate to the generic project-pack resolver.
# Detects the active project (if any) from per-project YAML configs. Always
# emits a systemMessage naming the loaded pack or noting generic mode;
# additionalContext (the WORKFLOW_PACK announcement) is what's conditional on
# a match. See scripts/resolve-project-pack.sh and packs/README.md.

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$dir/../scripts/resolve-project-pack.sh"
