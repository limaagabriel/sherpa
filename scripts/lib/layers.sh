#!/usr/bin/env bash
# Usage: source scripts/lib/layers.sh; is_layer <name>
# Input:  none to source; is_layer takes one name.
# Output: LAYERS, the one list of layer names; is_layer prints nothing.
# Exit:   0. is_layer returns 0 when the name is in LAYERS, 1 otherwise. Sourced only;
#   never run directly.

LAYERS=(frame shape implement analyze)

is_layer() {
  local l
  for l in "${LAYERS[@]}"; do [ "$l" = "$1" ] && return 0; done
  return 1
}
