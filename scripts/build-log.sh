#!/usr/bin/env bash
# Append one build-step telemetry event to the build-state log
# ($BUILD_LOG_FILE, default $HOME/.claude/.build-state/log.jsonl).
#
# Invoked by the read-only coordinators (/adversarial-build, /build-and-review)
# at each phase boundary. The coordinators' Bash is inspection-only and the
# `>` redirection verb is forbidden to them — this script encapsulates its own
# append, the same intentional exception as scripts/build-id.sh.
#
# All flags optional except --build-id, --coord, --phase, --event.
#
# Usage:
#   build-log.sh --build-id <id> --coord <adversarial-build|build-and-review> \
#                --phase <prep|vet|build|probe|deliver|decompose|tier|verify|review> \
#                --event <start|verdict|route|end> \
#                [--subtask <n>] [--verdict <V>] [--rewrite <n>] [--fix-loop <n>] \
#                [--cap-hit] [--hole-classes a,b,c] [--tier <t>] [--count <n>] \
#                [--model <m>] [--note "..."]

set -euo pipefail

LOG="${BUILD_LOG_FILE:-$HOME/.claude/.build-state/log.jsonl}"

build_id=""; coord=""; phase=""; event=""
subtask=""; verdict=""; rewrite=""; fix_loop=""
cap_hit="false"; hole_classes=""; tier=""; count=""; model=""; note=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-id)     build_id="$2"; shift 2 ;;
    --coord)        coord="$2"; shift 2 ;;
    --phase)        phase="$2"; shift 2 ;;
    --event)        event="$2"; shift 2 ;;
    --subtask)      subtask="$2"; shift 2 ;;
    --verdict)      verdict="$2"; shift 2 ;;
    --rewrite)      rewrite="$2"; shift 2 ;;
    --fix-loop)     fix_loop="$2"; shift 2 ;;
    --cap-hit)      cap_hit="true"; shift ;;
    --hole-classes) hole_classes="$2"; shift 2 ;;
    --tier)         tier="$2"; shift 2 ;;
    --count)        count="$2"; shift 2 ;;
    --model)        model="$2"; shift 2 ;;
    --note)         note="$2"; shift 2 ;;
    *) echo "build-log.sh: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

for req in build_id coord phase event; do
  if [[ -z "${!req}" ]]; then
    echo "build-log.sh: --${req//_/-} is required" >&2
    exit 2
  fi
done

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

classes_json="null"
if [[ -n "$hole_classes" ]]; then
  classes_json="$(printf '%s' "$hole_classes" | jq -R 'split(",") | map(select(length > 0))')"
fi

mkdir -p "$(dirname "$LOG")"

jq -nc \
  --arg ts "$ts" \
  --arg build_id "$build_id" \
  --arg coord "$coord" \
  --arg phase "$phase" \
  --arg event "$event" \
  --arg subtask "$subtask" \
  --arg verdict "$verdict" \
  --arg rewrite "$rewrite" \
  --arg fix_loop "$fix_loop" \
  --argjson cap_hit "$cap_hit" \
  --argjson hole_classes "$classes_json" \
  --arg tier "$tier" \
  --arg count "$count" \
  --arg model "$model" \
  --arg note "$note" '
  {
    ts: $ts, build_id: $build_id, coord: $coord, phase: $phase, event: $event,
    subtask: (if $subtask == "" then null else ($subtask | tonumber) end),
    verdict: $verdict,
    rewrite: (if $rewrite == "" then null else ($rewrite | tonumber) end),
    fix_loop: (if $fix_loop == "" then null else ($fix_loop | tonumber) end),
    cap_hit: (if $cap_hit then true else null end),
    hole_classes: $hole_classes,
    tier: $tier, count: (if $count == "" then null else ($count | tonumber) end),
    model: $model, note: $note
  }
  | with_entries(select(.value != null and .value != ""))
' >> "$LOG"
