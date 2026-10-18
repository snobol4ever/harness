#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the testpgms runner invoked on a scratch fixture, not a board (CEO-547)"
# test_gate_testpgms_grades_a_spitbol_post_mortem_through_the_one_error_voice.sh -- ceo CEO-1316 (2026-09-27), on Lon's word "I want to
# see TPgm go to 8/8. I'm tired of seeing that 1/8.": a spitbol_testpgms program whose sbl answer is a fatal post-mortem at rc 0 is GRADED,
# never marked OUTSIDE. util_spitbol_post_mortem.py removes SPITBOL's post-mortem block ONLY when it has exactly the measured shape and
# refuses rc 2 on any other; test_snobol4_spitbol_testpgms_suite.sh compares the rest of stdout byte for byte and the banner's line and
# statement with SCRIP's stderr through util_render_error_voice.py spitbol; the accounting is never graded (CEO-420 (b)).
#
# THE FIXTURE: OUTPUT = 'before', then INPUT(.INPUT,,72), which sbl -bf stops with ERROR 116 at statement 2 -- the shape of testpgms
# test4/test5 -- so the arms see a line printed before the raise survive the strip.
#   W   PREMISE: sbl answers the fixture with the exact post-mortem, and SCRIP's mode-3 stdout equals the stripped body
#   H1  the helper removes the exact block, prints the banner and statement 2, leaves "before"
#   H2  a missing blank line before the banner refuses rc 2
#   H3  throughput lines printed at execution time 0 ms refuse rc 2 (stopr prints them only above 0 ms)
#   H4  a time above 0 ms WITHOUT the throughput lines refuses rc 2; H5 the same time WITH all three is removed
#   H6  a stream with no banner returns rc 3 (the caller grades normally)
#   G   the runner on a one-program scratch suite: scored=1, m3 and m4 PASS, post-mortem graded=1, rc 0
#   R1  DISCRIMINATING: a mode-3 SCRIP whose error voice names statement 999 reds m3 (the voice arm) and still passes m4, rc 1
#   R2  DISCRIMINATING: a mode-3 SCRIP that loses its "before" line reds m3 (the stdout arm), rc 1
# FAIL_ONCE (recorded, hq_snobol4 2026-09-27): run against the runner as it stood on SCRIP 572981e49 (the one change stashed, the helper
#   present), G reds (the old arm read the post-mortem as UNSCORED: scored=0, rc 2) and R1/R2 red with it; the cure greens all nine.
# EXIT: 0 every arm passes . 1 an arm is red . 2 REFUSED (no oracle, stale binary, the premise moved, no pre-cure runner in history)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh"          || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
O="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
H="$HERE/util_spitbol_post_mortem.py"; RUNNER="$HERE/test_snobol4_spitbol_testpgms_suite.sh"
refuse() { echo "GATE UNPROVEN(2) [$GATE_NAME]: $*"; exit 2; }
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  RED  $1 -- $3"; red=$((red+1)); fi; }

mkdir -p "$T/fx"; printf "\tOUTPUT = 'before'\n\tINPUT(.INPUT,,72)\n\tOUTPUT = 'never'\nEND\n" > "$T/fx/testpm.spt"; : > "$T/fx/testpgms.in"
printf 'entry,heap_kb,stack_kb,compile_args,run_args\ntestpm,131072,4096,,\n' > "$T/fx/ALL.csv"
( cd "$T/fx" && timeout -k 5 30 "$O" -bf testpm.spt < testpgms.in > "$T/ora" 2>/dev/null ) || refuse "sbl -bf did not exit 0 on the fixture -- the premise moved"
python3 "$H" "$T/ora" "$T/body" > "$T/pm" 2>"$T/pm.err"; hrc=$?
[ "$hrc" = 0 ] || refuse "the helper does not accept sbl's post-mortem on the fixture (rc=$hrc: $(cat "$T/pm.err")) -- re-measure the shape"
( cd "$T/fx" && timeout -k 5 30 "$ROOT/scrip" testpm.spt < testpgms.in > "$T/m3" 2>/dev/null )
cmp -s "$T/body" "$T/m3" || refuse "SCRIP's mode-3 stdout differs from sbl's stripped body on the fixture -- the premise moved"
echo "  W    premise: sbl stops the fixture at statement $(awk -F'\t' '$1=="STATEMENT"{print $2}' "$T/pm") with a post-mortem; SCRIP's stdout equals the body"

[ "$(cat "$T/body")" = before ] && grep -qxF "STATEMENT	2" "$T/pm" && grep -q "^BANNER	testpm.spt(2) : ERROR 116 -- " "$T/pm" && arm H1 ok || arm H1 red "body [$(cat "$T/body")] pm [$(tr '\n' ' ' < "$T/pm")]"
sed '2d' "$T/ora" > "$T/h2"; python3 "$H" "$T/h2" /dev/null >/dev/null 2>&1; r=$?; [ "$r" = 2 ] && arm H2 ok || arm H2 red "rc=$r, want 2"
# ⛔ THE WITNESSES ARE DERIVED FROM A 0 ms BASE, NEVER FROM THE LIVE TIME (hq_snobol4 2026-09-28): under load sbl reports 1 ms or more and
# prints its own three throughput lines, so a sed keyed on "msec  0" matched nothing, H3 and H4 were the oracle's valid post-mortem, the helper
# rightly accepted them, and the gate read RED on a shape it never built. The base normalises the time to 0 and drops any throughput lines.
sed -e 's/^\(execution time msec  *\)[0-9][0-9]*$/\10/' -e '/^stmt \/ \(microsec\|millisec\|second\) /d' "$T/ora" > "$T/ora0"
sed 's/^\(execution time msec  *0\)$/\1\nstmt \/ microsec      0\nstmt \/ millisec      0\nstmt \/ second        0/' "$T/ora0" > "$T/h3"
grep -q "^stmt / second" "$T/h3" || refuse "could not build the H3 witness from sbl's post-mortem (no 'execution time msec 0' line)"
python3 "$H" "$T/h3" /dev/null >/dev/null 2>&1; r=$?; [ "$r" = 2 ] && arm H3 ok || arm H3 red "rc=$r, want 2"
sed 's/^\(execution time msec  *\)0$/\15/' "$T/ora0" > "$T/h4"; python3 "$H" "$T/h4" /dev/null >/dev/null 2>&1; r=$?; [ "$r" = 2 ] && arm H4 ok || arm H4 red "rc=$r, want 2"
sed 's/^\(execution time msec  *\)0$/\15\nstmt \/ microsec      0\nstmt \/ millisec      0\nstmt \/ second        0/' "$T/ora0" > "$T/h5"
python3 "$H" "$T/h5" "$T/h5.body" >/dev/null 2>&1; r=$?; { [ "$r" = 0 ] && [ "$(cat "$T/h5.body")" = before ]; } && arm H5 ok || arm H5 red "rc=$r, want 0 and body 'before'"
python3 "$H" "$T/fx/testpm.spt" /dev/null >/dev/null 2>&1; r=$?; [ "$r" = 3 ] && arm H6 ok || arm H6 red "rc=$r, want 3"

board() { printf '%s\n' "$1" | grep -E '^SPITBOL_TESTPGMS_BOARD '; }
# a board field is read by its NAME, never by its neighbours (util_board_field_matcher_census.py, CEO-839): fld <board> <name>
fld() { printf '%s\n' "$1" | tr ' ' '\n' | awk -F= -v k="$2" '$1==k {print $2; exit}'; }
want() { local b="$1"; shift; local kv; for kv in "$@"; do [ "$(fld "$b" "${kv%%=*}")" = "${kv#*=}" ] || return 1; done; }
out="$(cd "$ROOT" && SPITBOL_TESTPGMS_SUITE="$T/fx" timeout -k 5 300 bash "$RUNNER" 2>&1)"; rc=$?
b="$(board "$out")"
{ [ "$rc" = 0 ] && want "$b" scored=1 unscored=0 m3_pass=1 m3_fail=0 m4_pass=1 m4_fail=0 && printf '%s\n' "$out" | grep -q '^SPITBOL_TESTPGMS_POST_MORTEM graded=1 '; } \
  && arm G ok || arm G red "rc=$rc board [$b]; $(printf '%s\n' "$out" | grep -E 'REFUSE|RED ' | head -3 | tr '\n' ' ')"

REAL="$ROOT/scrip"; mkdir -p "$T/w1" "$T/w2"
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = --compile ] && exec "%s" "$@"; done\ne=$(mktemp); "%s" "$@" 2>"$e"; rc=$?; sed "s/; statement [0-9]*/; statement 999/" "$e" >&2; rm -f "$e"; exit $rc\n' "$REAL" "$REAL" > "$T/w1/scrip"
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = --compile ] && exec "%s" "$@"; done\n"%s" "$@" | grep -v "^before$"; exit ${PIPESTATUS[0]}\n' "$REAL" "$REAL" > "$T/w2/scrip"
chmod +x "$T/w1/scrip" "$T/w2/scrip"
out="$(cd "$ROOT" && SCRIP="$T/w1/scrip" SPITBOL_TESTPGMS_SUITE="$T/fx" timeout -k 5 300 bash "$RUNNER" 2>&1)"; rc=$?
{ [ "$rc" = 1 ] && want "$(board "$out")" m3_pass=0 m3_fail=1 m4_pass=1 m4_fail=0 && printf '%s\n' "$out" | grep -q 'RED  testpm m3 .*the error voice does not'; } \
  && arm R1 ok || arm R1 red "rc=$rc board [$(board "$out")]; $(printf '%s\n' "$out" | grep -E 'REFUSE|RED ' | head -2 | tr '\n' ' ')"
out="$(cd "$ROOT" && SCRIP="$T/w2/scrip" SPITBOL_TESTPGMS_SUITE="$T/fx" timeout -k 5 300 bash "$RUNNER" 2>&1)"; rc=$?
{ [ "$rc" = 1 ] && want "$(board "$out")" m3_pass=0 m3_fail=1 && printf '%s\n' "$out" | grep -q 'RED  testpm m3 .*first diff'; } \
  && arm R2 ok || arm R2 red "rc=$rc board [$(board "$out")]; $(printf '%s\n' "$out" | grep -E 'REFUSE|RED ' | head -2 | tr '\n' ' ')"

if [ "$red" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: $n arms"; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $red of $n arms red"; exit 1
