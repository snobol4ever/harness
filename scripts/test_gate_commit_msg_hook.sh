#!/usr/bin/env bash
# test_gate_commit_msg_hook.sh — the forbidden-trailer commit-msg hook, graded in BOTH directions.
#
# ⛔⭐ THE ACCEPT ARM IS THE DANGEROUS ONE, NOT THE REJECT ARM. A hook that fails to reject lets
# one bad trailer through; a hook that wrongly rejects stops EVERY seat's every commit at once
# (the row's own brief: "a hook that rejects clean messages stops all 20 clones"). So the
# accept cases here outnumber the reject cases on purpose, and they include the exact shape this
# policy's own documentation takes -- prose naming the trailers mid-sentence, which MUST stay
# committable or the policy could never be written down.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
HOOK="$S4E/SCRIP/.git/hooks/commit-msg"
PASS=0; FAIL=0
[ -x "$HOOK" ] || { echo "REFUSE (rc=2): no executable commit-msg hook at $HOOK -- run ../harness/scripts/install_commit_msg_hook.sh; cannot measure, not a pass"; exit 2; }
echo "=== commit-msg hook: forbidden trailers rejected, everything else accepted ==="
t="$(mktemp)"; trap 'rm -f "$t"' EXIT
check() { # check <want: reject|accept> <label> <message...>
    local want="$1" label="$2"; shift 2
    printf '%s\n' "$@" > "$t"
    if "$HOOK" "$t" >/dev/null 2>&1; then got=accept; else got=reject; fi
    if [ "$got" = "$want" ]; then echo "  PASS [$want] $label"; PASS=$((PASS+1))
    else echo "  FAIL [want=$want got=$got] $label"; FAIL=$((FAIL+1)); fi
}
# ── must REJECT: the four harness-default shapes ──────────────────────────────────────────────
check reject "Co-Authored-By trailer"        "fix a thing" "" "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
check reject "Co-authored-by lowercase"      "fix a thing" "" "Co-authored-by: Someone <a@b>"
check reject "Claude-Session trailer"        "fix a thing" "" "Claude-Session: https://claude.ai/code/session_01ABC"
check reject "Generated-with line"           "fix a thing" "" "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
check reject "Generated-with, no emoji"      "fix a thing" "" "Generated with [Claude Code](https://claude.com/claude-code)"
check reject "bare session URL line"         "fix a thing" "" "https://claude.ai/code/session_01XYZ"
check reject "leading whitespace"            "fix a thing" "" "   Co-Authored-By: Claude <x@y>"
# ── must ACCEPT: everything a real snobol4ever message does ───────────────────────────────────
check accept "one-line clean message"        "clean message"
check accept "subject + body"                "emit: fix the thing" "" "Because the other thing was wrong." "Measured: 1672/0 both modes."
check accept "prose naming the trailers"     "policy: commits carry no Co-Authored-By: or Generated with [Claude Code] trailers" "" "This is the documentation of the rule and it must stay committable."
check accept "prose naming a session URL"    "docs: explain that a https://claude.ai/code/session_ URL must never appear as a trailer" "" "Mid-sentence mention, not a trailer line."
check accept "trailer word inside a sentence" "note that Co-Authored-By: is forbidden here" "" "still fine -- the term is not line-initial as a trailer."
check accept "a real Signed-off-by"          "fix a thing" "" "Signed-off-by: LCherryholmes <lcherryh@yahoo.com>"
check accept "git comment lines are ignored" "clean subject" "" "# Co-Authored-By: Claude <x@y>" "# Please enter the commit message for your changes."
check accept "empty-ish message"             ""
echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ $((PASS+FAIL)) -gt 0 ] || { echo "REFUSE (rc=2): graded ZERO cases -- cannot measure, not a pass"; exit 2; }
[ "$FAIL" -eq 0 ]
