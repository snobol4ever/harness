#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_snocone_returns_codegen.sh -- computed DONE-WHEN for the snocone-returns-codegen row.
# NARROWED 2026-08-27 per hq_C ruling `ruling-narrow-the-donewhen-keep-the-row-open` (seat02 session 7):
# checks only bugs #1/#2/#3 (mode-3 Error 22, CLASS-C argument marshalling, `nreturn` codegen
# referencing the wrong floater-return symbol) plus the beauty.sc ladder past `trace.sc` plus the
# SNOBOL4 gate. The by-name-value symptom on fn_nreturn.sc (Error 239) is EXPECTED and TOLERATED here --
# it is not Snocone-specific, this row did not cause it, and it is tracked separately in
# nreturn-by-name-value-broken. This gate does NOT rebuild scrip (a pristine build is the caller's job,
# consistent with every other test_gate_*.sh) -- it refuses loudly if the binary is missing instead of
# silently building or silently passing.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -u
SCRIP_DIR="$S4E/SCRIP"
SCRIP="${SCRIP:-$SCRIP_DIR/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
FR="$CORPUS/tests/snocone/ladder/prog/fn_freturn.sc"
NR="$CORPUS/tests/snocone/ladder/prog/fn_nreturn.sc"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
GATE_NAME=snocone-returns-codegen
. "$SCRIP_DIR/../harness/scripts/lib_gate.sh"   # gate_three_way: absent-line-is-UNPROVEN(2), never this row's fail()

fail() { echo "⛔ NOT DONE: $*" >&2; exit 1; }

[ -x "$SCRIP" ] || fail "scrip not built at $SCRIP -- run 'make pristine' in SCRIP/ first"
[ -f "$FR" ] || fail "witness not found: $FR"
[ -f "$NR" ] || fail "witness not found: $NR"
cd "$SCRIP_DIR" || fail "cannot cd to $SCRIP_DIR"
EXPECT_FR="$(printf 'pos5-ok\nneg-freturn-ok')"

# --- fn_freturn.sc (bug #2) must be FULLY correct, both modes ---
"$SCRIP" --run "$FR" < /dev/null > "$TMP/fr3.out" 2> "$TMP/fr3.err"; rc=$?
[ "$rc" -eq 0 ] && [ "$(cat "$TMP/fr3.out")" = "$EXPECT_FR" ] || fail "fn_freturn.sc m3: rc=$rc out=$(cat "$TMP/fr3.out") err=$(cat "$TMP/fr3.err")"

"$SCRIP" --compile "$FR" > "$TMP/fr.s" 2> "$TMP/fr.cerr" || fail "fn_freturn.sc m4 compile: $(cat "$TMP/fr.cerr")"
gcc -c "$TMP/fr.s" -o "$TMP/fr.o" 2> "$TMP/fr.aerr" || fail "fn_freturn.sc m4 assemble: $(cat "$TMP/fr.aerr")"
gcc "$TMP/fr.o" -L"$SCRIP_DIR/out" -lscrip_rt -lm -Wl,-rpath,"$SCRIP_DIR/out" -o "$TMP/fr.bin" 2> "$TMP/fr.lerr" || fail "fn_freturn.sc m4 link: $(cat "$TMP/fr.lerr")"
"$TMP/fr.bin" < /dev/null > "$TMP/fr4.out" 2> "$TMP/fr4.err"; rc=$?
[ "$rc" -eq 0 ] && [ "$(cat "$TMP/fr4.out")" = "$EXPECT_FR" ] || fail "fn_freturn.sc m4: rc=$rc out=$(cat "$TMP/fr4.out") err=$(cat "$TMP/fr4.err")"

# --- fn_nreturn.sc: bug #1/#3 symptoms must be ABSENT; by-name-value Error 239 is TOLERATED ---
"$SCRIP" --run "$NR" < /dev/null > "$TMP/nr3.out" 2> "$TMP/nr3.err"; rc=$?
{ [ "$rc" -lt 128 ] && [ "$rc" -ne 124 ]; } || fail "fn_nreturn.sc m3 CRASHED/HUNG (rc=$rc): $(cat "$TMP/nr3.err")"
grep -qE 'unresolved forward reference|Error 22\b' "$TMP/nr3.out" "$TMP/nr3.err" && fail "fn_nreturn.sc m3 regressed to bug #1/#3: $(cat "$TMP/nr3.err")"

"$SCRIP" --compile "$NR" > "$TMP/nr.s" 2> "$TMP/nr.cerr" || fail "fn_nreturn.sc m4 compile (bug #3 regression?): $(cat "$TMP/nr.cerr")"
gcc -c "$TMP/nr.s" -o "$TMP/nr.o" 2> "$TMP/nr.aerr" || fail "fn_nreturn.sc m4 assemble: $(cat "$TMP/nr.aerr")"
gcc "$TMP/nr.o" -L"$SCRIP_DIR/out" -lscrip_rt -lm -Wl,-rpath,"$SCRIP_DIR/out" -o "$TMP/nr.bin" 2> "$TMP/nr.lerr" || fail "fn_nreturn.sc m4 link (bug #3 regression?): $(cat "$TMP/nr.lerr")"
"$TMP/nr.bin" < /dev/null > "$TMP/nr4.out" 2> "$TMP/nr4.err"; rc=$?
{ [ "$rc" -lt 128 ] && [ "$rc" -ne 124 ]; } || fail "fn_nreturn.sc m4 CRASHED/HUNG (rc=$rc): $(cat "$TMP/nr4.err")"

# --- beauty.sc self-host ladder: must get PAST trace.sc (bug #3's old blocker must not reappear) ---
bash ../harness/scripts/test_snocone_beauty_self_host.sh --corpus "$CORPUS" --scrip "$SCRIP" > "$TMP/ladder.out" 2>&1
if [ -f /tmp/sb6_scr.err ]; then
  grep -qE "unresolved forward reference|undefined reference to \`RETURN'" /tmp/sb6_scr.err && fail "beauty ladder: trace.sc's old nreturn blocker is back: $(cat /tmp/sb6_scr.err)"
fi

# --- SNOBOL4 corpus gate: FAIL=0 SKIP=0 both modes, read fresh (CEO-s272 law: the shape, not a cached number) ---
# ⛔ An absent/killed run of this sub-gate (rc=2, e.g. programs KILLED at its per-program timeout under
# fleet load) is UNPROVEN, not a failed DONE-WHEN for THIS row -- fail() would read a busy box as a
# Snocone regression (row a-refusal-reported-in-the-vocabulary-of-a-red-absent-line-read-as-unparseable,
# seat15/hq_T 2026-09-05).
# ⛔ A SCRATCH RUNGS, NEVER THE REAL ONE (ceo CEO-1302 (c), coo 2026-09-27): this arm ran test_corpus_snobol4.sh over the whole
# 1991-entry rungs under the one-runner fixture exemption, so every seat that ran this gate ran a SnoRungs board -- the coo's control
# arm of 2026-09-26 made two passes and appended 7964 rows. It grades the rungs entries this row is about (every one whose source
# uses NRETURN or FRETURN, XFAIL and outside-baseline entries left out) and the runner's 23 demos, in a git world with no remote,
# through util_scratch_snobol4_rungs.py, with a scratch progress table and no leaderboard write. The regex below also missed the
# runner's line since c18cb9811 put "both-modes PASS=" first, so this arm read UNPROVEN after every full pass; it reads the line now.
SNO_ROOT="$TMP/snoroot"
python3 ../harness/scripts/util_scratch_snobol4_rungs.py "$SNO_ROOT" '\b[NF]RETURN\b' > "$TMP/snoroot.out" 2>&1 \
  || { echo "⚠️ UNPROVEN(2), not a fail: the scratch SNOBOL4 rungs could not be built -- $(tail -2 "$TMP/snoroot.out")" >&2; exit 2; }
sn_n=$(sed -n 's/^SCRATCH_RUNGS entries=\([0-9]*\) .*/\1/p' "$TMP/snoroot.out")
snout=$(S4E_HOME="$SNO_ROOT" S4E_PROGRESS_DB="$TMP/snoroot_progress.tsv" S4E_SCORE_NO_WRITE="gate ${0##*/}: a scratch rungs" RUNGS_ENTRY_FLOOR="$sn_n" bash ../harness/scripts/test_corpus_snobol4.sh 2>&1); snrc=$?
# rc==1 is that script's OWN "measured, mode-4 regressed" signal -- decide it directly rather than via
# gate_three_way's pattern match, since a real rc=1 prints a DIFFERENT (sparser) "GATE FAIL:" line that
# would otherwise look just as absent as a genuine kill; this must stay a real fail(), never UNPROVEN.
[ "$snrc" -eq 1 ] && fail "SNOBOL4 gate not clean (measured, rc=1): $(printf '%s\n' "$snout" | tail -8)"
snline=$(gate_three_way "test_corpus_snobol4.sh" "$snrc" "$snout" '✅ GATE OK: .*m3 PASS=[0-9]+ FAIL=0 .* m4 PASS=[0-9]+ FAIL=0 SKIP=0 .* MISSING=0'); sngrc=$?
if [ "$sngrc" -eq 2 ]; then
    echo "⚠️ UNPROVEN(2), not a fail: the SNOBOL4 corpus gate could not be measured (rc=$snrc) -- see stderr for the real cause" >&2
    exit 2
fi

echo "✅ snocone-returns-codegen narrowed DONE-WHEN: bugs #1/#2/#3 fixed both modes, ladder past trace.sc, SNOBOL4 gate clean"
exit 0
