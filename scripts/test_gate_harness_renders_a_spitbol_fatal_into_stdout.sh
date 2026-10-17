#!/usr/bin/env bash
# test_gate_harness_renders_a_spitbol_fatal_into_stdout.sh -- A SPITBOL FATAL IS GRADABLE (ceo CEO-1344 on hq_snobol4's measurement,
# the cfo seconding; the coo's row instruments-a-spitbol-fatal-is-gradable-the-one-reader-renders-scrips-stderr-error-through-the-
# spitbol-equivalence-list-into-stdout-and-masks-the-run-summary-lines-ceo-1344).
# THE DEFECT: x64 sbl -bf prints its fatal block ON STDOUT (and stderr), so a ref cut from the oracle for a program that ends in a
# run-time fatal carries the block, and SCRIP's one error voice (stderr) could never match it -- six programs were ungradable by
# construction (Budne tab.sno, rewind1.sno; Dotnet 1brc.sno, asgn1.sno; SnoRungs simple_output_62, user_function_arbno_rpos_1).
# THE CURE, PROVEN HERE ON A WITNESS WHOSE REF IS CUT FROM THE LIVE ORACLE AT GATE TIME:
#   1  corpus_suite_harness.py (the ONE reader) renders SCRIP's stderr block through util_render_error_voice.py into sbl's stdout
#      block and appends it before the compare: the witness reads PASS in BOTH modes; the run-summary lines are masked beside the data;
#   2  FAIL-ONCE through the seam S4E_FATAL_RENDER=0: the same witness reads FAIL in both modes (the render is load-bearing);
#   3  the MERGED capture shape (2>&1, the bash package runners' capture) renders byte-identical to sbl's own merged text, masked;
#   4  test_snobol4_csnobol4_suite.sh (the Budne runner, its own loop) grades the witness PASS in both modes over a scratch suite;
#   5  and that scratch run WRITES NO SCORE ROW: the real SUITES.tsv is byte-identical before and after (the fixture door, COO-216).
# EXIT: 0 every arm holds; 1 an arm failed; 2 could not measure (no oracle, no binary, stale binary). Population printed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=harness_renders_a_spitbol_fatal_into_stdout
gate_parse_args "$@"
H="$HERE/corpus_suite_harness.py"; RV="$HERE/util_render_error_voice.py"; BR="$HERE/test_snobol4_csnobol4_suite.sh"
gate_require "$H" "corpus_suite_harness.py" || exit 2
gate_require "$RV" "util_render_error_voice.py" || exit 2
gate_require "$BR" "test_snobol4_csnobol4_suite.sh" || exit 2
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary" || exit 2
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null)"; SBLF="$(sbl_lang_flags 2>/dev/null)"
[ -n "$SBL" ] && [ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no SNOBOL4 oracle (sbl_correctness_bin) -- the ref is cut from the oracle or not at all"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"; . "$HERE/lib_suites_tsv.sh" || { echo "REFUSING(2): cannot load lib_suites_tsv.sh"; exit 2; }
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"; mkdir -p "$SCRATCH" || exit 2
W=$(mktemp -d "$SCRATCH/gate_fatal_XXXXXX") || exit 2
trap '[ -n "${W:-}" ] && rm -rf "$W"' EXIT INT TERM
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
MASK_RE='^(stmts executed       |execution time msec  |REGENERATIONS        |memory used \(bytes\)  |memory left \(bytes\)  )([0-9]+|-)$'

# THE WITNESS: output, then a run-time fatal, then output the fatal must cut off
printf '\tOUTPUT = "before"\n\tY = 0\n\tX = 1 / Y\n\tOUTPUT = "after"\nEND\n' > "$W/fatal_witness.sno"
( cd "$W" && timeout -k 5 20 "$SBL" $SBLF fatal_witness.sno < /dev/null > "$W/ref.stdout" 2> "$W/ref.stderr" ); rcS=$?
( cd "$W" && timeout -k 5 20 "$SBL" $SBLF fatal_witness.sno < /dev/null > "$W/ref.merged" 2>&1 )
grep -q ' : ERROR [0-9][0-9][0-9] -- ' "$W/ref.stdout" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the oracle printed no fatal block on stdout for the witness (rc=$rcS) -- the premise moved: $(head -3 "$W/ref.stdout" | tr '\n' '|')"; gate_stamp; exit 2; }
# the suite pair: one banner-block entry, the ref the oracle's stdout, the mask sidecar the five run-summary lines (one source: the renderer's list)
python3 - "$H" "$RV" "$W" <<'EOF'
import sys, importlib.util
sys.path.insert(0, __import__("os").path.dirname(sys.argv[1]))
import corpus_suite_harness as h, util_render_error_voice as rv
W = sys.argv[3]
b = h.make_banner(1, "fatal_witness")
src = open(W + "/fatal_witness.sno").read()
open(W + "/ALL.sno", "w").write(b + "\n" + src)
ref = open(W + "/ref.stdout").read()
open(W + "/ALL.ref", "w").write(b + "\n" + ref)
with open(W + "/ALL.mask", "w") as m:
    m.write("# the run-summary lines of a SPITBOL fatal block, oracle-internal (CEO-1344)\n")
    for rx, why in rv.FATAL_SUMMARY_MASKS:
        m.write("*\t%s\t%s\n" % (rx, why))
EOF
listed="$(python3 "$H" list "$W/ALL.sno" "$W/ALL.ref" 2>&1)"
[ "$listed" = "fatal_witness" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the scratch pair does not list one entry fatal_witness: $listed"; gate_stamp; exit 2; }

echo "--- ARM 1: the harness grades the witness PASS in both modes (ref cut from sbl stdout, rc $rcS) ---"
o1=$(cd "$ROOT" && S4E_PROGRESS_DB="$W/p1.tsv" timeout -k 5 120 python3 "$H" run "$W/ALL.sno" "$W/ALL.ref" --modes m3,m4 2>&1); r1=$?
b1=$(grep -m1 '^SUITE_BOARD ' <<<"$o1")
ck "1 rc 0, m3_pass=1 m4_pass=1 over 1 entry" '[ "$r1" = 0 ] && grep -q " m3_pass=1 " <<<"$b1" && grep -q " m4_pass=1 " <<<"$b1" && grep -q " total=1 " <<<"$b1"'
[ "$r1" = 0 ] || printf '%s\n' "$o1" | grep -vE '^(DECLARED|RUNTIME|CEO-409)' | tail -6 | sed 's/^/      /'

echo "--- ARM 2: FAIL-ONCE -- with the render off (S4E_FATAL_RENDER=0) the same witness reads FAIL in both modes ---"
o2=$(cd "$ROOT" && S4E_FATAL_RENDER=0 S4E_PROGRESS_DB="$W/p2.tsv" timeout -k 5 120 python3 "$H" run "$W/ALL.sno" "$W/ALL.ref" --modes m3,m4 2>&1); r2=$?
b2=$(grep -m1 '^SUITE_BOARD ' <<<"$o2")
ck "2 rc 1, m3_fail=1 m4_fail=1 -- the render is load-bearing, not decoration" '[ "$r2" = 1 ] && grep -q " m3_fail=1 " <<<"$b2" && grep -q " m4_fail=1 " <<<"$b2"'

echo "--- ARM 3: the merged capture shape (2>&1) renders byte-identical to the oracle's own merged text, masked ---"
( cd "$W" && timeout -k 5 20 "$SCRIP" --run fatal_witness.sno < /dev/null 2>&1 | python3 "$RV" spitbol --fatal-merged | grep -vE "$MASK_RE" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$W/m3.merged.rendered" )
grep -vE "$MASK_RE" "$W/ref.merged" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$W/ref.merged.masked"
ck "3 SCRIP m3 2>&1 through --fatal-merged == sbl 2>&1, the five summary lines masked, trailing blanks dropped" 'cmp -s "$W/m3.merged.rendered" "$W/ref.merged.masked"'
cmp -s "$W/m3.merged.rendered" "$W/ref.merged.masked" || diff "$W/m3.merged.rendered" "$W/ref.merged.masked" | head -8 | sed 's/^/      /'

echo "--- ARM 4: the Budne runner (its own loop, merged capture) grades the witness PASS in both modes over a scratch suite ---"
mkdir -p "$W/csn"; cp "$W/fatal_witness.sno" "$W/csn/fatal_witness.sno"; cp "$W/ref.merged" "$W/csn/fatal_witness.ref"; cp "$W/ALL.mask" "$W/csn/ALL.mask"
: > "$W/csn/ALL.ref"   # the mask shim derives ALL.mask from ALL.ref beside it and refuses when the ref is absent (the real suite has both)
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n1,fatal_witness,fatal_witness,csnobol4_suite,5,0,0,131072,4096,,\n' > "$W/csn/ALL.csv"
mark_before="$(suites_real_mark)"
o4=$(cd "$ROOT" && CSNOBOL4_SUITE="$W/csn" S4E_PROGRESS_DB="$W/p4.tsv" S4E_ONE_RUNNER_FIXTURE="gate $GATE_NAME: the Budne runner over a one-program scratch suite, not a board" timeout -k 5 300 bash "$BR" 2>&1); r4=$?
p4m3=$(awk -F'\t' '$8=="fatal_witness" && $9=="m3" {print $10}' "$W/p4.tsv" 2>/dev/null | tail -1); p4m4=$(awk -F'\t' '$8=="fatal_witness" && $9=="m4" {print $10}' "$W/p4.tsv" 2>/dev/null | tail -1)
ck "4 the runner's progress rows read fatal_witness m3 PASS and m4 PASS (rc $r4)" '[ "$p4m3" = PASS ] && [ "$p4m4" = PASS ]'
[ "$p4m3" = PASS ] && [ "$p4m4" = PASS ] || { printf '%s\n' "$o4" | grep -iE 'fatal_witness|REFUS|PASS|FAIL' | head -6 | sed 's/^/      /'; }

echo "--- ARM 5: that scratch run wrote NO score row (the fixture door of util_score_row.py, COO-216) ---"
ck "5a the real SUITES.tsv is byte-identical before and after the fixture run (another session's row write excused by its history line)" 'suites_real_untouched "$mark_before"'
ck "5b the runner said so: publishes nothing (S4E_ONE_RUNNER_FIXTURE or a scratch progress table)" 'grep -qE "publishes nothing|publishes no row" <<<"$o4"'

echo "--- ARM 6: the Dotnet runner (live oracle diff, no ref, its own loop) grades the witness PASS in both modes over a scratch suite ---"
DR="$HERE/test_snobol4_dotnet_suite.sh"
if [ -f "$DR" ]; then
  mkdir -p "$W/dot"; cp "$W/fatal_witness.sno" "$W/dot/fatal_witness.sno"; cp "$W/ALL.mask" "$W/dot/ALL.mask"
  cp "$W/fatal_witness.sno" "$W/dot/excluded_witness.sno"
  printf '\tY = 0\n\tX = 1 / Y\nEND\n' > "$W/dot/silent_fatal_witness.sno"
  printf 'excluded_witness.sno\tNOT_SPITBOL_DIALECT\tgate fixture: a program whose fatal under sbl -bf is the CSNOBOL4 feature it uses, excluded by CEO-1286\n' > "$W/dot/EXCLUDED.tsv"
  printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n1,fatal_witness,fatal_witness,dotnet,5,0,0,131072,4096,,\n2,excluded_witness,excluded_witness,dotnet,5,0,0,131072,4096,,\n3,silent_fatal_witness,silent_fatal_witness,dotnet,3,0,0,131072,4096,,\n' > "$W/dot/ALL.csv"
  mkdir -p "$W/dbg"
  o6=$(cd "$ROOT" && DOTNET_SUITE="$W/dot" DOTNET_DEBUG_DIR="$W/dbg" S4E_PROGRESS_DB="$W/p6.tsv" S4E_ONE_RUNNER_FIXTURE="gate $GATE_NAME: the Dotnet runner over a one-program scratch suite, not a board" timeout -k 5 300 bash "$DR" 2>&1); r6=$?
  p6m3=$(awk -F'\t' '$8=="fatal_witness" && $9=="m3" {print $10}' "$W/p6.tsv" 2>/dev/null | tail -1); p6m4=$(awk -F'\t' '$8=="fatal_witness" && $9=="m4" {print $10}' "$W/p6.tsv" 2>/dev/null | tail -1)
  ck "6a the Dotnet runner's progress rows read fatal_witness m3 PASS and m4 PASS (rc $r6), the program named FATAL_GRADED" '[ "$p6m3" = PASS ] && [ "$p6m4" = PASS ] && grep -q "FATAL_GRADED.* fatal_witness" <<<"$o6"'
  [ "$p6m3" = PASS ] && [ "$p6m4" = PASS ] || { printf '%s\n' "$o6" | grep -iE 'fatal_witness|REFUS|DOTNET_BOARD|FATAL' | head -6 | sed 's/^/      /'; echo "      what the runner compared (oracle vs m3), first lines of the diff:"; diff "$W/dbg/fatal_witness.oracle" "$W/dbg/fatal_witness.m3" 2>&1 | head -8 | sed 's/^/        /'; echo "      m3 stderr:"; head -4 "$W/dbg/fatal_witness.err3" 2>/dev/null | sed 's/^/        /'; }
  p6x=$(awk -F'\t' '$8=="excluded_witness" && $9=="m3" {print $10}' "$W/p6.tsv" 2>/dev/null | tail -1)
  ck "6c a program EXCLUDED.tsv names keeps its fatal as the dialect refusal: UNGRADED, never graded through the rendered block (the d6c775c13 defect)" '[ "$p6x" = UNGRADED ] && ! grep -q "FATAL_GRADED.* excluded_witness" <<<"$o6"'
  ck "6b and wrote no score row either" 'suites_real_untouched "$mark_before"'
  # ⭐ A FATAL WITH NOTHING PRINTED BEFORE IT (the cto 1957d1d0f, reviewed by the coo 2026-10-02): Dotnet asgn1 printed nothing before
  # its ERROR 038, and the render joined the empty stdout to the block with a newline -- a fourth leading empty line where sbl prints
  # three -- so it read FAIL in both modes on that line alone. The separator follows non-empty stdout only.
  p6sm3=$(awk -F'\t' '$8=="silent_fatal_witness" && $9=="m3" {print $10}' "$W/p6.tsv" 2>/dev/null | tail -1); p6sm4=$(awk -F'\t' '$8=="silent_fatal_witness" && $9=="m4" {print $10}' "$W/p6.tsv" 2>/dev/null | tail -1)
  ck "6d a fatal with no output before it reads PASS in m3 and m4 (got $p6sm3 $p6sm4): no separator line after an empty stdout" '[ "$p6sm3" = PASS ] && [ "$p6sm4" = PASS ]'
  . "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$W/pre" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $W/pre"; exit 2; }
  rm -f "$W/pre/harness/scripts/test_snobol4_dotnet_suite.sh"
  sed 's|then if \[ -n "\$1" \]; then printf .%s\\n%s. "\$1" "\$r"; else printf .%s. "\$r"; fi; else|then printf '"'"'%s\\n%s'"'"' "$1" "$r"; else|' "$DR" > "$W/pre/harness/scripts/test_snobol4_dotnet_suite.sh"
  if cmp -s "$DR" "$W/pre/harness/scripts/test_snobol4_dotnet_suite.sh"; then ck "6e fail-once: the pre-1957d1d0f join is plantable" 'false'
  else
    (cd "$ROOT" && S4E_HOME="$S4E" DOTNET_SUITE="$W/dot" DOTNET_DEBUG_DIR="$W/dbg" S4E_PROGRESS_DB="$W/p6e.tsv" S4E_ONE_RUNNER_FIXTURE="gate $GATE_NAME: the pre-cure Dotnet runner over a scratch suite, not a board" timeout -k 5 300 bash "$W/pre/harness/scripts/test_snobol4_dotnet_suite.sh" > /dev/null 2>&1)
    p6em3=$(awk -F'\t' '$8=="silent_fatal_witness" && $9=="m3" {print $10}' "$W/p6e.tsv" 2>/dev/null | tail -1)
    ck "6e fail-once: the pre-1957d1d0f join reads the silent fatal red in m3 (got ${p6em3:-nothing})" '[ -n "$p6em3" ] && [ "$p6em3" != PASS ]'
  fi
else
  echo "  (no Dotnet runner beside this gate: arm 6 not built)"
fi

echo "------------------------------------------------------------"
echo "population: $n check(s) over one oracle-cut witness (sbl rc $rcS, $(wc -l < "$W/ref.stdout") stdout lines, $(wc -l < "$W/ref.merged") merged lines), two graders (the harness both modes, the Budne runner both modes), the real SUITES.tsv watched"
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
