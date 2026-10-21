#!/bin/bash
# Compiles and runs the state-machine harnesses.
#
# The guard is the part of PhoneFree that is hardest to reason about and
# easiest to break: a budget that is spent by use, recharged by being away,
# and must not be refilled by a re-entry inside one sitting. None of that is
# visible in a screenshot, and the simulator cannot reproduce a real lock or
# a suspension. So the rules live here, in plain Swift, and can be checked
# in a second.
#
# Usage:  Tests/run.sh
#
# Each harness is a standalone `main.swift` compiled against the same
# Shared/ files the app uses — so a change to the state machine that breaks
# a rule breaks a check here, with a name that says which rule.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

SOURCES=(
    "$ROOT/Shared/PhoneFreeUsage.swift"
    "$ROOT/Shared/PhoneFreeWindow.swift"
)

# The harnesses that assert. The dump is a tool, not a test: it prints the
# state machine's decisions so a new rule can be watched rather than only
# checked.
SUITES=(guardbudget redhold devicetests)
TOOLS=(guarddump)

failed=0

for suite in "${SUITES[@]}"; do
    echo "── $suite"
    if ! swiftc "$ROOT/Tests/$suite/main.swift" "${SOURCES[@]}" \
        -o "$BUILD/$suite" 2>"$BUILD/$suite.log"; then
        echo "   COMPILE FAILED"
        sed 's/^/   /' "$BUILD/$suite.log"
        failed=1
        continue
    fi

    if "$BUILD/$suite" >"$BUILD/$suite.out" 2>&1; then
        grep -c '^PASS' "$BUILD/$suite.out" | tr -d ' ' \
            | xargs -I{} echo "   {} checks passed"
    else
        echo "   FAILED"
        grep '^FAIL' "$BUILD/$suite.out" | sed 's/^/   /'
        failed=1
    fi
done

for tool in "${TOOLS[@]}"; do
    echo "── $tool (tool, not a test)"
    if ! swiftc "$ROOT/Tests/$tool/main.swift" "${SOURCES[@]}" \
        -o "$BUILD/$tool" 2>"$BUILD/$tool.log"; then
        echo "   COMPILE FAILED"
        sed 's/^/   /' "$BUILD/$tool.log"
        failed=1
        continue
    fi
    "$BUILD/$tool" | sed 's/^/   /'
done

if [ "$failed" -eq 0 ]; then
    echo
    echo "All checks passed."
else
    echo
    echo "Some checks failed."
fi

exit "$failed"
