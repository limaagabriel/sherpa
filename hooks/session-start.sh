#!/usr/bin/env bash
# Sherpa SessionStart hook: delegate to the generic project-pack resolver.
# Detects the active project (if any) from per-project YAML configs and emits a
# WORKFLOW_PACK announcement; silent when no project matches. See
# scripts/resolve-project-pack.sh and packs/README.md.

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$dir/../scripts/resolve-project-pack.sh"
