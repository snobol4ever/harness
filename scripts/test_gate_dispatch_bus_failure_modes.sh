#!/usr/bin/env bash
# test_gate_dispatch_bus_failure_modes.sh -- DONE-WHEN gate for fix-dispatch-bus-two-failure-modes (HQ s256).
#
# THE TWO FAILURE MODES FROM THE ORIGINAL BRIEF are each already fixed and each has its own dedicated
# negative-injection suite; this gate is the single canonical entry point that PROVES BOTH ARE STILL FIXED
# by composing those suites, then closes the one gap neither of them covers.
#   (1) identity depends on clone freshness, silent phantom-mailbox invention  -> test_gate_postoffice_identity.sh
#   (2) dispatch-by-inbox-alone (three sources of truth that could disagree)   -> test_gate_s4e_picker_v2.sh
#       (run here with --self-check too, so mode 2's own negative-injection proof runs as part of THIS gate)
#
# THE GAP THIS FILE ACTUALLY CLOSES: seat07's live report, q-s4e-msg-banner-attribution-undercount --
# next() and banner both resolved MULTIPLE of a seat's own claims by glob (alphabetical) file order, so a
# seat holding two open/assigned claims could be served, resumed, or attributed to the WRONG one. Cured by
# rank-sorting Pass 1/Pass 2 of next() the same way V2-1 already rank-sorts Pass 3 (free rows), and by
# having banner actually USE the topic done(topic) was already passing it (the call was `banner "$topic"
# ...` all along; banner just never read $2 for anything but the "-v" flag).
#
# ⛔ NEGATIVE-TESTED: --self-check re-runs every assertion below with the pre-fix (glob-order) answer
# injected in place of the real one -- same technique test_gate_s4e_picker_v2.sh already uses -- and
# requires itself to FAIL. A gate that cannot say NO is not a gate (seat16 measured 31/105 that cannot).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="${S4E_MSG_BIN:-$HERE/s4e_msg.sh}"   # override = the real negative test
SELF=0; [ "${1:-}" = "--self-check" ] && SELF=1
# ⛔ FOUND BY HAND (fix-dispatch-bus-two-failure-modes, s266): Pass 3 self-invokes as `"$0" claim <topic>`,
# a direct exec, not `bash "$0"` -- a script copy that lost its +x bit (e.g. `git show HEAD:path > /tmp/x`)
# fails that exec silently inside the `if ... >/dev/null 2>&1` guard and every row reads as unclaimable,
# which looks exactly like "next() is broken" and is not. Refuse up front instead of misreporting it as one.
[ -x "$MSG" ] || { echo "⛔ $MSG is not executable -- Pass 3's \"\$0 claim ...\" self-invokes it directly, not via bash (set S4E_MSG_BIN to an executable copy)" >&2; exit 2; }
printf '  subject: %s%s\n' "$MSG" "$([ "$SELF" = 1 ] && echo '  [--self-check: injecting pre-fix answers]')"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no(){ fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual  : %s\n' "$1" "$2" "$3"; }
run_component() { # $1 = label, $2 = script, rest = its args. Folds a whole sub-gate's rc into ONE check here.
  local label="$1" script="$2" out rc; shift 2
  out="$(S4E_MSG_BIN="$MSG" bash "$script" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then ok "$label"; else no "$label" "exit 0" "exit $rc -- tail:$(printf '%s' "$out" | tail -3 | tr '\n' '|')"; fi
}

echo "== component: FAILURE MODE 1 -- identity depends on clone freshness =="
# No self-check knob of its own (negative-injection was proved by hand against the pre-patch script, per
# its own header); always run normally here -- this component answers "is mode 1 still fixed," period.
run_component "postoffice identity suite (V2-3/V2-4, 18 negative-injection checks)" "$HERE/test_gate_postoffice_identity.sh"

echo "== component: FAILURE MODE 2 -- dispatch-by-inbox-alone is only a next()-overridable suggestion =="
if [ "$SELF" = 1 ]; then run_component "picker v2 suite, --self-check (proves IT can say NO)" "$HERE/test_gate_s4e_picker_v2.sh" --self-check
else run_component "picker v2 suite (rank-sort Pass 3 + assign-is-the-lock, 19 checks)" "$HERE/test_gate_s4e_picker_v2.sh"; fi

echo "== NEW: resume ordering -- next()/banner must not resolve a seat's OWN multiple claims by glob order =="
# Topics are named so ALPHABETICAL order and RANK order actively DISAGREE: aa-high-rank sorts first but
# carries the WORSE (higher/less urgent) rank; zz-low-rank sorts last but is the one the fleet actually
# wants served first. A glob-order implementation gets every check below wrong, not just wrong sometimes.
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/root/harness/scripts"
printf '%s\n' '#!/bin/sh' 'echo HANDOFF COMPLETE' 'exit 0' > "$T/root/harness/scripts/handoff_status.sh"; chmod +x "$T/root/harness/scripts/handoff_status.sh"
run() { local seat="$1"; shift; S4E_POST="$T/po" S4E_HOME="$T/root" S4E_SEAT="$seat" S4E_NO_BANNER=1 bash "$MSG" "$@" 2>&1; }
newpo() { rm -rf "$T/po"; mkdir -p "$T/po"/{claims,tasks,seatAA/inbox,hq_C/inbox}
  printf '9\taa-high-rank\tb\tFREE\n1\tzz-low-rank\tb\tFREE\n' > "$T/po/QUEUE.tsv"; }

echo "-- A: next() Pass 1, two ASSIGNED-BY-but-not-yet-RUNNING claims --"
newpo
run hq_C assign seatAA aa-high-rank >/dev/null; run hq_C assign seatAA zz-low-rank >/dev/null; run seatAA clear >/dev/null
out="$(run seatAA next)"
[ "$SELF" = 1 ] && out="ASSIGNED->RUNNING aa-high-rank (dispatched by hq_C)"   # inject the pre-fix glob-first answer
case "$out" in *"ASSIGNED->RUNNING zz-low-rank"*) ok "Pass 1 serves the lower-rank assignment first, not the alphabetically-first one";;
  *) no "Pass 1 rank order among MY OWN claims" "ASSIGNED->RUNNING zz-low-rank" "$(echo "$out" | head -1)";; esac

echo "-- B: next() Pass 2, two already-open unfinished claims --"
newpo
printf 'seatAA\nRUNNING\n' > "$T/po/claims/aa-high-rank.claim"; printf 'seatAA\nRUNNING\n' > "$T/po/claims/zz-low-rank.claim"
out="$(run seatAA next)"
[ "$SELF" = 1 ] && out="RESUME aa-high-rank (yours, unfinished — s4e_msg.sh done aa-high-rank when the handoff clause is met)"
case "$out" in *"RESUME zz-low-rank"*) ok "Pass 2 resumes the lower-rank open claim first, not the alphabetically-first one";;
  *) no "Pass 2 rank order among MY OWN claims" "RESUME zz-low-rank" "$(echo "$out" | head -1)";; esac

# ⛔⭐ THE ROW CELL, READ AS A CELL (hq_B 2026-09-13, row `instruments-the-stop-banner-wraps-twenty-six-
# of-its-forty-two-lines-past-eighty-columns`). These three checks used to substring-match "row <topic>"
# against the WHOLE banner, which worked only while the banner printed one long "· row <topic>" line. That
# line was 337 display columns and wrapped into five unreadable rows in Lon's terminal, so the verdict is now
# a fitted grid and the topic sits in its own labelled cell: "  row     OPEN <topic>".
# ⛔ WHAT IS BEING PRESERVED, EXACTLY: this gate's subject is ATTRIBUTION -- which row the banner picks --
# and that property is unchanged and still strictly asserted. Only the rendering it reads moved. The matcher
# is ANCHORED to the row line rather than loosened to a bare topic search: a bare *"<topic>"* would also
# match the topic appearing anywhere else in the banner, which would make all three checks pass for the
# wrong reason -- the weaker test is the trap here, not the stricter one. The SELF=1 injections below are
# rewritten into the same shape, so the fail-once proof still reds.
# ⛔⛔ ARMS C, D AND E ARE DELETED, NOT DISABLED (Lon 2026-09-13, in-chat to hq_S, verbatim: "See that banner
# you just output. The header says suite pass/tot gap date state. Delete whatever produced that. I want it
# gone. I've ordered that removed." then "I want the entire text gone. Not just the header.").  All three
# asserted that `banner` PRINTS a `row ...` cell attributing the seat to a topic, and the printed banner no
# longer exists: s4e_msg.sh banner emits nothing at all.  A gate over a deleted subject cannot be green, and
# rewriting them to read BOARD.md instead would be a DIFFERENT property than the one they were cut for.
# ⛔ WHAT IS NOT LOST: the rank-sort resume ORDER those arms rode on is still graded by A and B above, which
# read next() output rather than the banner.  Only the display assertion is gone.

printf '\n  %s: %d passed, %d failed\n' "$([ "$fail" -eq 0 ] && echo PASS || echo '⛔ FAIL')" "$pass" "$fail"
if [ "$SELF" = 1 ]; then
  if [ "$fail" -gt 0 ]; then printf '  ✅ SELF-CHECK PASSED: with pre-fix (glob-order) behaviour injected this gate said NO (%d failures). It can fail.\n' "$fail"; exit 0
  else printf '  ⛔ SELF-CHECK FAILED: pre-fix behaviour was injected and the gate still said PASS. This gate is BLIND — do not cite it.\n'; exit 1; fi; fi
[ "$fail" -eq 0 ]
