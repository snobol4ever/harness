#!/bin/bash
# test_gate_vanroy_bucket_rule.sh -- pins the van Roy board's MEASURED bucket rule (row
# prolog-vanroy-21-board-two-number-basis, hq_B ruling 2026-09-01).
#
# THE RULE: a kernel is MEASURED only when it carries an AGREE row for EVERY RIVAL ENGINE the grid publishes --
# not >=1. A kernel promoted on its friendliest rival while another rival disagreed is a board citing the number
# it likes, which is the `grep AGREE` defect wearing better manners.
#
# ⭐ WHY THIS GATE EXISTS AT ALL. The clause was left unimplemented on 2026-09-01 with the reason "I could not TEST
# the difference at this tree" -- true of the LIVE data (no kernel has a mixed rival verdict today) and false of the
# rule, which is a pure function of a TSV and so is testable with a six-line fixture. ⛔ THE GENERAL FORM: "the data
# cannot distinguish these two rules today" is an argument for a FIXTURE, never for shipping the looser rule. A rule
# that only ever meets data it agrees with is not measured, it is merely unrefuted.
#
# ⛔⛔ AND THE LITERAL ALL-ENGINES READING IS A TRAP THIS GATE PINS SHUT (fixture E). The grid publishes FOUR engines
# -- gnu swi m3 m4 -- and m3/m4 are UNPROVEN for EVERY kernel BY CONSTRUCTION, not by disagreement: every vanroy
# kernel is the exact shape that crashes them (PZ-4). Gating promotion on SCRIP's own mode rows pins MEASURED at 0
# until PZ-4 lands. The rivals are the axis; SCRIP's modes are the subject being measured. A bucket that can never
# fill is a broken instrument, not a strict one.
#
# It grades the REAL selection code through `bench_prolog_vanroy.sh --measured-from <tsv>` -- ⛔ never a second copy
# of the awk: a gate that restates the rule it guards proves the two copies agree, never that either is right.
# Reads only text; needs no build and no rival engine. REFUSES rc=2 when it cannot measure, never skip-as-success.
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME self-derive
BOARD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bench_prolog_vanroy.sh"
[ -f "$BOARD" ] || { echo "⛔ REFUSED-TO-GRADE (rc=2): board script missing: $BOARD" >&2; exit 2; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
HDR=$'# fixture -- synthetic, never a measurement\nkernel\tengine\tangle1_rate\tangle2_rate\tratio\tverdict\tdisk_inblock\tdisk_oublock'
fail=0; n=0
# mkfix <name> <rows...>  -- rows are "kernel engine verdict"
mkfix() { local f="$WORK/$1.tsv"; shift; printf '%s\n' "$HDR" > "$f"; local r; for r in "$@"; do set -- $r; printf '%s\t%s\t1\t1\t1.0\t%s\t0\t0\n' "$1" "$2" "$3" >> "$f"; done; echo "$f"; }
# want <label> <fixture> <expected MEASURED list, space-separated, may be empty>
want() {
    local label="$1" fix="$2" exp="$3" got out rc
    n=$((n+1)); out=$(bash "$BOARD" --measured-from "$fix" 2>&1); rc=$?
    if [ $rc -ne 0 ]; then echo "⛔ FAIL [$label]: rulecheck exited rc=$rc" >&2; echo "$out" | sed 's/^/    /' >&2; fail=$((fail+1)); return; fi
    got=$(printf '%s\n' "$out" | sed -n 's/^MEASURED: *//p' | sed 's/ *$//')
    if [ "$got" = "$exp" ]; then echo "✅ PASS [$label]: MEASURED='$got'"
    else echo "⛔ FAIL [$label]: MEASURED='$got' expected='$exp'" >&2; echo "$out" | sed 's/^/    /' >&2; fail=$((fail+1)); fi
}
echo "== van Roy MEASURED bucket rule -- every rival must AGREE =="
# A. THE DIFFERENCE ITSELF: one rival AGREEs, the other DISAGREEs. The >=1 rule promotes it; the rule promotes nothing.
want "mixed rivals are NOT measured" "$(mkfix mixed 'mixed gnu AGREE' 'mixed swi DISAGREE')" ""
# B. Full house promotes -- the rule must still be able to say YES, or it is just a refusal with extra steps.
want "all rivals AGREE -> measured" "$(mkfix full 'both gnu AGREE' 'both swi AGREE')" "both"
# C. Silence is not agreement: an AGREE from gnu with swi never having measured the kernel is still a partial board.
want "missing rival row is NOT measured" "$(mkfix partial 'onlygnu gnu AGREE' 'other gnu AGREE' 'other swi AGREE')" "other"
# D. A duplicated kernel,engine row must not fake a full house (dedupe guard in tn_measured_kernels).
want "duplicate row cannot fake a full house" "$(mkfix dup 'd gnu AGREE' 'd gnu AGREE' 'd swi DISAGREE')" ""
# E. ⛔ THE TRAP: real shape -- both rivals AGREE, SCRIP's own m3/m4 UNPROVEN. MUST stay MEASURED. If someone
#    "tightens" the rule to all ENGINES rather than all RIVALS, this fixture goes red and says why.
want "m3/m4 UNPROVEN must not veto a rival verdict" "$(mkfix selfrows 'k gnu AGREE' 'k swi AGREE' 'k m3 UNPROVEN' 'k m4 UNPROVEN')" "k"
# F. The rival set is DERIVED FROM THE DATA: publish a third rival and the rule tightens with no code change.
want "a third rival tightens automatically" "$(mkfix third 'k gnu AGREE' 'k swi AGREE' 'k yap DISAGREE' 'j gnu AGREE' 'j swi AGREE' 'j yap AGREE')" "j"
# G. DISAGREE must never be reachable by substring (AGREE is a substring of DISAGREE).
want "DISAGREE is not AGREE" "$(mkfix sub 's gnu DISAGREE' 's swi DISAGREE')" ""
# H. A grid with no rival at all has no axis -> REFUSE rc=2, never a plausible empty board.
n=$((n+1)); f="$(mkfix norival 'k m3 UNPROVEN' 'k m4 UNPROVEN')"
out=$(bash "$BOARD" --measured-from "$f" 2>&1); rc=$?
if [ $rc -eq 2 ]; then echo "✅ PASS [no rival engine -> REFUSE rc=2]"
else echo "⛔ FAIL [no rival engine]: rc=$rc, expected 2 (refusal, not an empty board)" >&2; echo "$out" | sed 's/^/    /' >&2; fail=$((fail+1)); fi
# I. CONTROL ARM ON LIVE DATA: today's committed grid must be UNCHANGED by the tightening -- deriv and fib both
#    carry AGREE from both rivals, so the board this gate defends did not move when the rule got stricter.
TRI="$(ls -1t "$S4E/corpus/benchmarks/prolog"/triangulation-*.tsv 2>/dev/null | head -1)"
if [ -z "$TRI" ]; then echo "⛔ REFUSED-TO-GRADE (rc=2): no committed triangulation-*.tsv -- control arm has no source" >&2; exit 2; fi
want "live grid unchanged by the tightening ($(basename "$TRI"))" "$TRI" "deriv fib"
echo
if [ $fail -eq 0 ]; then echo "✅ GATE GREEN: $n/$n checks -- MEASURED requires every rival, and m3/m4 cannot veto."; exit 0; fi
echo "⛔ GATE RED: $fail of $n checks failed." >&2; exit 1
