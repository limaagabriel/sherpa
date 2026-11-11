#!/usr/bin/env bash
# Usage: source scripts/lib/dirs.sh; packs_dirs | shared_dir
# Input:  env SHERPA_CONFIG_DIR, WORKFLOW_PACKS_DIR, XDG_CONFIG_HOME, HOME.
# Output: packs_dirs prints the workspace packs dirs, one per line:
#   $SHERPA_CONFIG_DIR/projects if set, else $WORKFLOW_PACKS_DIR itself if set, else
#   ${XDG_CONFIG_HOME:-$HOME/.config}/sherpa/projects plus the legacy
#   $HOME/.claude/sherpa/projects read-fallback dir.
#   shared_dir prints ${SHERPA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/sherpa}/shared.
# Exit:   0. Sourced only; never run directly.

packs_dirs() {
  if [ -n "${SHERPA_CONFIG_DIR:-}" ]; then
    printf '%s\n' "$SHERPA_CONFIG_DIR/projects"
  elif [ -n "${WORKFLOW_PACKS_DIR:-}" ]; then
    printf '%s\n' "$WORKFLOW_PACKS_DIR"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/sherpa/projects" "$HOME/.claude/sherpa/projects"
  fi
}

shared_dir() {
  printf '%s\n' "${SHERPA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/sherpa}/shared"
}
