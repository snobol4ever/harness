#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_nreturn_by_name_value_broken.sh -- computed DONE-WHEN for nreturn-by-name-value-broken.
# RE-POINTED 2026-08-27 (seat02 session 2) per hq_C's own recommendation on this row: the original two
# witnesses ($mk()='stored' and n07_nreturn.sno) are both malformed or misread relative to the SPITBOL
# oracle (see hq_C's FINDING/commit 22069a1c) -- this gate checks the REAL, oracle-grounded gap instead:
# Snocone `<call>() = value` (no `$`) must deliver the SAME result the classic `DEFINE`+`NRETURN` idiom
# already delivers (`STORE() = 43`, SPITBOL manual p.133), in both integer and string form, without
# regressing the classic witness, the SNOBOL4 gate, or the Icon/Raku/Prolog smokes.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -u
SCRIP_DIR="$S4E/SCRIP"
SCRIP="${SCRIP:-$SCRIP_DIR/scrip}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
GATE_NAME=nreturn-by-name-value-broken
. "$SCRIP_DIR/../harness/scripts/lib_gate.sh"   # gate_three_way: absent-line-is-UNPROVEN(2), never this row's fail()

fail() { echo "⛔ NOT DONE: $*" >&2; exit 1; }

[ -x "$SCRIP" ] || fail "scrip not built at $SCRIP -- run 'make pristine' in SCRIP/ first"
cd "$SCRIP_DIR" || fail "cannot cd to $SCRIP_DIR"

cat > "$TMP/mk_int.sc" <<'EOF'
function mkname() { mkname = .dummy; nreturn; }
mkname() = 43;
OUTPUT = dummy;
EOF
cat > "$TMP/mk_str.sc" <<'EOF'
function mkname() { mkname = .dummy; nreturn; }
mkname() = 'stored';
OUTPUT = dummy;
EOF
cat > "$TMP/classic43.sno" <<'EOF'
        DEFINE('store()dummy')                    :(main)
store   store = .dummy                            :(NRETURN)
main    store() = 43
        OUTPUT = dummy
END
EOF

check_one() {
    local src="$1" expect="$2" label="$3"
    "$SCRIP" --run "$src" < /dev/null > "$TMP/o3" 2>"$TMP/e3"; local rc=$?
    { [ "$rc" -eq 0 ] && [ "$(cat "$TMP/o3")" = "$expect" ]; } || fail "$label m3: rc=$rc out=$(cat "$TMP/o3") err=$(cat "$TMP/e3")"
    "$SCRIP" --compile "$src" > "$TMP/c.s" 2>"$TMP/cerr" || fail "$label m4 compile: $(cat "$TMP/cerr")"
    gcc -c "$TMP/c.s" -o "$TMP/c.o" 2>"$TMP/aerr" || fail "$label m4 assemble: $(cat "$TMP/aerr")"
    gcc "$TMP/c.o" -L"$SCRIP_DIR/out" -lscrip_rt -lm -Wl,-rpath,"$SCRIP_DIR/out" -o "$TMP/c.bin" 2>"$TMP/lerr" || fail "$label m4 link: $(cat "$TMP/lerr")"
    "$TMP/c.bin" < /dev/null > "$TMP/o4" 2>"$TMP/e4"; rc=$?
    { [ "$rc" -eq 0 ] && [ "$(cat "$TMP/o4")" = "$expect" ]; } || fail "$label m4: rc=$rc out=$(cat "$TMP/o4") err=$(cat "$TMP/e4")"
}

# --- the real gap: Snocone call-LHS NRETURN-by-name assignment, both an int and a string payload ---
check_one "$TMP/mk_int.sc" "43" "Snocone mkname()=43"
check_one "$TMP/mk_str.sc" "stored" "Snocone mkname()='stored'"

# --- non-regression: the classic oracle-verified idiom this Snocone form mirrors ---
check_one "$TMP/classic43.sno" "43" "classic STORE()=43"

# --- SNOBOL4 corpus gate: FAIL=0 SKIP=0 both modes, read fresh (CEO-s272 law: the shape, not a number) ---
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

# --- Icon/Raku smokes: zero FAIL both modes (their own scripts already enforce HARD zero-FAIL) ---
bash ../harness/scripts/test_smoke_icon.sh > "$TMP/icon.out" 2>&1 || fail "Icon smoke not clean: $(tail -8 "$TMP/icon.out")"
bash ../harness/scripts/test_smoke_raku.sh > "$TMP/raku.out" 2>&1 || fail "Raku smoke not clean: $(tail -8 "$TMP/raku.out")"

# --- Prolog smoke: tolerate ONLY the pre-existing 'clause' failure (rc=1 with exactly that FAIL) ---
bash ../harness/scripts/test_smoke_prolog.sh > "$TMP/prolog.out" 2>&1
prc=$?
if [ "$prc" -ne 0 ]; then
    fails="$(grep -oE '\[m[234] FAIL *\] [a-zA-Z0-9_]+' "$TMP/prolog.out" | awk '{print $NF}' | sort -u)"
    [ "$fails" = "clause" ] || fail "Prolog smoke has a NEW failure beyond the known pre-existing 'clause': [$fails]"
fi

echo "✅ nreturn-by-name-value-broken DONE-WHEN: Snocone NRETURN-by-name assignment matches the classic oracle-verified idiom, no regressions"
exit 0
