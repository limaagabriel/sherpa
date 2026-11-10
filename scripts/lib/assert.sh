#!/usr/bin/env bash
# Usage: source scripts/lib/assert.sh   (the caller sets fail=0 first)
# Input:  each helper takes <label> <actual> <expected>.
# Output: prints "FAIL [<label>]: ..." and sets fail=1 on a mismatch; silent otherwise.
# Exit:   0. Sourced only; never run directly.

assert_contains() { case "$2" in *"$3"*) ;; *) echo "FAIL [$1]: expected contains: $3 -- got: $2"; fail=1 ;; esac; }
assert_not_contains() { case "$2" in *"$3"*) echo "FAIL [$1]: expected NOT contains: $3 -- got: $2"; fail=1 ;; esac; }
assert_eq() { [ "$2" = "$3" ] || { echo "FAIL [$1]: expected: $3 -- got: $2"; fail=1; }; }
assert_exit() { [ "$2" -eq "$3" ] || { echo "FAIL [$1]: expected exit $3, got $2"; fail=1; }; }
