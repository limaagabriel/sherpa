#!/usr/bin/env bash
# Usage: source scripts/lib/rules-targets.sh
# Purpose: BLOCK_FILE_MAP, the files build-rules.sh scans for <!-- shared:<block> --> markers
#   (repo-relative; run from the repo root). Data only. Sourced only; never run directly.

# Block -> file map: files to scan for <!-- shared:<block> --> markers.
BLOCK_FILE_MAP=(
  skills/frame/SKILL.md
  skills/shape/SKILL.md
  skills/implement/SKILL.md
  skills/analyze/SKILL.md
  agents/codebase-explorer.md
  agents/frame-reviewer.md
  agents/readiness-reviewer.md
  agents/structure-reviewer.md
  agents/engineering-reviewer.md
  agents/quality-reviewer.md
  agents/code-reviewer.md
  agents/analysis-reviewer.md
  protocols/lenses/correctness.md
  protocols/lenses/readability.md
)
