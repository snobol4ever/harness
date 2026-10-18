#!/usr/bin/env bash
# test_gate_s_artifacts_verifier_stale_binary_refuses.sh -- THE ACCEPTANCE GATE for the stale-binary preflight in
# util_verify_s_artifacts_owed.sh (row s-artifacts-verifier-refuses-when-scrip-predates-the-newest-src-commit).
#
# WHAT IT PROVES, in BOTH directions, hermetically and in under a second:
#   (a) STALE -> REFUSE : a ./scrip whose mtime predates the newest src/ change makes the verifier exit rc=2 with
#       a REFUSED-TO-GRADE verdict. ⛔ It must NOT print an owed count: an OWED number BLOCKS a handoff, so a stale
#       binary would block it on debt that does not exist on origin (measured hq_B 2026-09-02: OWED 26 at rung-6
#       HEAD from a binary built 17 minutes before rung 6 landed; 0 owed after make pristine).
#   (b) FRESH -> PROCEED : a current binary passes the preflight and the run continues to the next check. Without
#       this arm the gate would pass against a script that refuses unconditionally, which is a different lie.
#   (c) ABSENT -> REFUSE : no binary at all still refuses rc=2 (the pre-existing contract, kept).
#   (d) The refusal is ACTIONABLE: it names both timestamps and the cure. A refusal that does not say what to do
#       sends the reader to doubt the gate, which is exactly the failure this row exists to stop.
#
# ⛔ HERMETIC AND NON-DESTRUCTIVE: every arm points the script under test at a THROWAWAY binary path via SCRIP=
# and at a deliberately-absent CORPUS, so the real ./scrip is never touched (not even its mtime -- faking currency
# on the real binary to test a currency check would be the same class of lie the check exists to catch) and no
# clone, build or regen ever runs. Arms (b) and (c) reach the corpus check and stop there; that rc=2 is EXPECTED
# and is the proof the preflight let them past, so each arm asserts on the OUTPUT TEXT, never on rc alone.
# SUT= overrides the script under test -- used to prove this gate FAILS against the pre-cure verifier (fail-once).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SUT="${SUT:-$HERE/util_verify_s_artifacts_owed.sh}"
refuse() { echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$SUT" ] || refuse "script under test not found: $SUT"
[ -d "$ROOT/src" ] || refuse "no $ROOT/src -- the preflight has no reference point to compare against"
newest_src="$(find "$ROOT/src" -type f -printf '%T@\n' 2>/dev/null | sort -rn | head -1 | cut -d. -f1)"
[ -n "$newest_src" ] || refuse "could not read any mtime under $ROOT/src"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/gate_stale_bin.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$WORK"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
run_sut() { CORPUS="$WORK/deliberately-absent" bash "$SUT" --skip-pristine 2>&1; }
echo "=== gate: util_verify_s_artifacts_owed.sh refuses on a stale binary (newest src/ mtime $newest_src) ==="

echo "--- (a) STALE binary -> REFUSE rc=2, and NO owed count ---"
stale="$WORK/scrip_stale"; : > "$stale"; chmod +x "$stale"; touch -d '2020-01-01 00:00:00' "$stale"
so_ok="$WORK/rt_ok.so"; : > "$so_ok"; touch "$so_ok"   # pinned fresh: this arm must prove the BINARY refused, not the runtime
out="$(SCRIP="$stale" SCRIP_RT="$so_ok" run_sut)"; rc=$?
[ "$rc" -eq 2 ] && ck ok "stale binary exits rc=2 (got $rc)" || ck no "stale binary must exit rc=2, got $rc"
grep -q 'REFUSED-TO-GRADE' <<<"$out" && ck ok "stale run says REFUSED-TO-GRADE" || ck no "stale run must say REFUSED-TO-GRADE"
grep -qi 'PREDATES src/' <<<"$out" && ck ok "refusal names the cause (binary predates src/)" || ck no "refusal must name the cause"
grep -q 'make pristine' <<<"$out" && ck ok "refusal names the cure (make pristine)" || ck no "refusal must name the cure: make pristine"
grep -q '2020-01-01' <<<"$out" && ck ok "refusal prints the binary's timestamp" || ck no "refusal must print the binary's timestamp"
grep -q "\[$newest_src\]" <<<"$out" && ck ok "refusal prints the src/ timestamp it compared against" || ck no "refusal must print the src/ timestamp"
grep -qE '^S-ARTIFACTS-OWED-TOTAL' <<<"$out" && ck no "⛔ stale run printed an owed total — an OWED count BLOCKS a handoff on debt that is not on origin" || ck ok "stale run prints NO owed total"
grep -qE 'VERDICT: (CLEAN|OWED)' <<<"$out" && ck no "⛔ stale run reached a CLEAN/OWED verdict — it cannot measure and must not pretend to" || ck ok "stale run reaches no CLEAN/OWED verdict"

echo "--- (b) FRESH binary -> preflight PASSES and the run proceeds ---"
fresh="$WORK/scrip_fresh"; : > "$fresh"; chmod +x "$fresh"; touch "$fresh"
# ⛔ THIS ARM MUST PIN THE .so TOO, AND UNTIL THE .so PREFLIGHT EXISTED IT DID NOT HAVE TO. It pinned a fresh
# BINARY and let the runtime come from the LIVE TREE -- which was stale on the very tree that added the .so
# check, so this arm went red for a reason it does not test. ⭐ A test arm that leaves a variable it is not
# testing bound to the live tree is FLAKY BY CONSTRUCTION; it passed for years only because nothing looked at
# that variable. Pin every input the subject reads, not just the one under test.
so_fresh="$WORK/rt_fresh.so"; : > "$so_fresh"; touch "$so_fresh"
out="$(SCRIP="$fresh" SCRIP_RT="$so_fresh" run_sut)"; rc=$?
grep -q 'build-currency OK' <<<"$out" && ck ok "fresh binary passes the preflight" || ck no "fresh binary must pass the preflight (else the check refuses unconditionally)"
grep -qi 'PREDATES src/' <<<"$out" && ck no "⛔ fresh binary was wrongly called stale" || ck ok "fresh binary is not called stale"
grep -q 'corpus repo not found' <<<"$out" && ck ok "run proceeded past the preflight to the next check" || ck no "run must proceed past the preflight (expected the corpus check to be reached)"

echo "--- (d) STALE out/libscrip_rt.so -> REFUSE rc=2 (row stale-binary-preflight-also-covers-out-libscrip-rt-so) ---"
# ⛔ THE .so IS THE ARTIFACT EVERY `nm -D` VERDICT ACTUALLY READS, and the preflight never looked at it. It lags
# src/ exactly as ./scrip can: a 13:37 .so against a 14:16 src reported `exec_stmt` as STILL EXPORTED after the
# source deletion. ⭐ The dangerous direction is the FALSE GREEN -- a stale OLDER .so still exports what source
# removed and cannot show what source added -- so a clean symbol surface proves nothing about origin.
# The binary is held FRESH in these arms on purpose: it proves the .so is refused ON ITS OWN, not as a
# side-effect of the older binary check that already existed.
so_stale="$WORK/rt_stale.so"; : > "$so_stale"; touch -d '2020-01-01 00:00:00' "$so_stale"
out="$(SCRIP="$fresh" SCRIP_RT="$so_stale" run_sut)"; rc=$?
[ "$rc" -eq 2 ] && ck ok "stale .so exits rc=2 (got $rc)" || ck no "stale .so must exit rc=2, got $rc"
grep -q 'libscrip_rt' <<<"$out" && ck ok "refusal NAMES out/libscrip_rt.so" || ck no "refusal must name libscrip_rt.so — an instrument quotes its reference"
grep -qi 'PREDATES src/' <<<"$out" && ck ok ".so refusal names the cause" || ck no ".so refusal must name the cause"
grep -q '2020-01-01' <<<"$out" && ck ok ".so refusal prints the artifact timestamp" || ck no ".so refusal must print the artifact timestamp"
grep -q "\[$newest_src\]" <<<"$out" && ck ok ".so refusal prints the src/ timestamp it compared against" || ck no ".so refusal must print the src/ timestamp"
grep -qE '^S-ARTIFACTS-OWED-TOTAL' <<<"$out" && ck no "⛔ stale .so run printed an owed total" || ck ok "stale .so run prints NO owed total"
grep -qE 'VERDICT: (CLEAN|OWED)' <<<"$out" && ck no "⛔ stale .so run reached a CLEAN/OWED verdict" || ck ok "stale .so run reaches no CLEAN/OWED verdict"

echo "--- (e) FRESH .so -> preflight passes and the run proceeds ---"
out="$(SCRIP="$fresh" SCRIP_RT="$so_fresh" run_sut)"; rc=$?
grep -qi 'PREDATES src/' <<<"$out" && ck no "⛔ fresh .so was wrongly called stale" || ck ok "fresh .so is not called stale"
grep -q 'corpus repo not found' <<<"$out" && ck ok "run proceeded past BOTH preflights" || ck no "run must proceed past both preflights"

echo "--- (f) ABSENT .so -> REFUSE rc=2 and say so (never a silent pass) ---"
out="$(SCRIP="$fresh" SCRIP_RT="$WORK/no_such_rt.so" run_sut)"; rc=$?
[ "$rc" -eq 2 ] && ck ok "absent .so exits rc=2 (got $rc)" || ck no "absent .so must exit rc=2, got $rc"
grep -qi 'not built' <<<"$out" && ck ok "absent .so says 'not built'" || ck no "absent .so must say 'not built'"

echo "--- (c) ABSENT binary -> still REFUSE rc=2 (pre-existing contract kept) ---"
out="$(SCRIP="$WORK/no_such_scrip" SCRIP_RT="$so_ok" run_sut)"; rc=$?
[ "$rc" -eq 2 ] && ck ok "absent binary exits rc=2 (got $rc)" || ck no "absent binary must exit rc=2, got $rc"
grep -qi 'not built' <<<"$out" && ck ok "absent binary says 'not built'" || ck no "absent binary must say 'not built'"

echo "------------------------------------------------------------"
if [ "$fails" -ne 0 ]; then echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; fi
echo "✅ GATE PASS: $checks/$checks checks"; exit 0
