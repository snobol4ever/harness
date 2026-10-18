#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_multifile_initialization_runs_every_file.sh -- EVERY POSITIONAL PROLOG FILE'S DIRECTIVES RUN, IN FILE ORDER.
# Row prolog-multifile-initialization-only-first-file-root-graph-wired (minted seat09 2026-09-06, cured hq_C same day).
#
# THE DEFECT THIS PINS: the driver records ONE lowering segment per positional source file and calls lower_pl_stage2
# once per segment. Each call builds its own root graph and registers its own "main" proc, and pl_new_proc's
# `main_mod < 0` guard makes the FIRST one win. So `scrip a.pl b.pl` ran a.pl's directives and SILENTLY dropped
# b.pl's -- exit 0, no output, no error. The swi_tests runner always passes the real entry point (its wrapper)
# LAST, so this alone held that whole suite at 0/114 in both modes.
# THE CURE: adjacent Prolog segments are coalesced into one segment before lowering, so multi-file lowers exactly
# like the concatenated file -- which is the arm (d) control below.
#
# WHAT IT PROVES, in four directions so a silent compiler cannot pass it:
#   (a) BOTH files' goals run when BOTH carry a directive -- this is the cure, and it is what first-wins broke.
#   (b) ORDER IS FILE ORDER, asserted by running the SAME two files BOTH WAYS and demanding the outputs swap.
#       Without this arm a "make the LAST file win" cure -- which the oracle disproves -- would pass.
#   (c) A directive-less FIRST file does not swallow the second file's goal (seat09's original minimal repro).
#   (d) The CONCATENATED single file agrees with the two-file form: multi-file must not be its own dialect.
#   (e) The oracle is ASSERTED, never assumed: swipl is run on every arm and REFUSES if its answer moved.
# ⛔ Hermetic: every program is written under mktemp; nothing in corpus/ is read or written.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP (a test that cannot measure REFUSES, never skips-as-success)"
SWIPL=/usr/bin/swipl; [ -x "$SWIPL" ] || refuse "no swipl at $SWIPL -- the oracle premise cannot be checked"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no $ROOT/out/libscrip_rt.so -- the m4 arm cannot link"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_plmulti.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
printf 'helper(X) :- X = 1.\n'                                        > "$W/quiet.pl"
printf 'one :- write(one_ran), nl.\n:- initialization(one).\n'        > "$W/one.pl"
printf 'two :- write(two_ran), nl.\n:- initialization(two).\n'        > "$W/two.pl"
cat "$W/one.pl" "$W/two.pl"                                           > "$W/cat12.pl"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
oracle(){ timeout -k 5 30 "$SWIPL" -q -g true -t halt "$@" </dev/null 2>/dev/null; }
echo "=== gate: multi-file prolog -- every file's directives run, in file order ==="
echo "--- (e) the ORACLE premise, asserted on every arm ---"
exp_12="$(oracle "$W/one.pl" "$W/two.pl")"; exp_21="$(oracle "$W/two.pl" "$W/one.pl")"
exp_q2="$(oracle "$W/quiet.pl" "$W/two.pl")"; exp_cat="$(oracle "$W/cat12.pl")"
[ "$exp_12"  = "$(printf 'one_ran\ntwo_ran')" ] && ck ok "oracle one.pl two.pl -> one_ran,two_ran" || refuse "oracle premise moved: one.pl two.pl printed [$exp_12]"
[ "$exp_21"  = "$(printf 'two_ran\none_ran')" ] && ck ok "oracle two.pl one.pl -> two_ran,one_ran (order follows file order)" || refuse "oracle premise moved: two.pl one.pl printed [$exp_21]"
[ "$exp_q2"  = "two_ran" ]                      && ck ok "oracle quiet.pl two.pl -> two_ran" || refuse "oracle premise moved: quiet.pl two.pl printed [$exp_q2]"
[ "$exp_cat" = "$exp_12" ]                      && ck ok "oracle concatenated == oracle two-file" || refuse "oracle premise moved: concatenated printed [$exp_cat] vs [$exp_12]"
for m in m3 m4; do
  echo "--- $m ---"
  run(){ if [ "$m" = m3 ]; then timeout -k 5 60 "$SCRIP" "$@" </dev/null 2>/dev/null; else
           s="$W/out.s"; b="$W/out.bin"; rm -f "$s" "$b"
           timeout -k 5 90 "$SCRIP" --compile -o "$s" "$@" </dev/null >/dev/null 2>&1 || return 97
           timeout -k 5 90 gcc -no-pie -o "$b" "$s" -L"$ROOT/out" -lscrip_rt -lm >/dev/null 2>&1 || return 98
           LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 60 "$b" </dev/null 2>/dev/null; fi; }
  out="$(run "$W/one.pl" "$W/two.pl")"; rc=$?
  [ "$rc" -eq 0 ] && ck ok "$m (a) two directive files: rc=0" || ck no "$m (a) two directive files: rc=$rc, expected 0"
  [ "$out" = "$exp_12" ] && ck ok "$m (a) BOTH files' goals ran, in order" || ck no "$m (a) printed [$out], oracle says [$exp_12] -- a dropped file's goal is a SILENT wrong answer (rc stays 0)"
  out="$(run "$W/two.pl" "$W/one.pl")"
  [ "$out" = "$exp_21" ] && ck ok "$m (b) reversing the files reverses the output (file order, not first- or last-wins)" || ck no "$m (b) printed [$out], oracle says [$exp_21]"
  out="$(run "$W/quiet.pl" "$W/two.pl")"
  [ "$out" = "$exp_q2" ] && ck ok "$m (c) a directive-less first file does not swallow the second's goal" || ck no "$m (c) printed [$out], oracle says [$exp_q2]"
  out="$(run "$W/cat12.pl")"
  [ "$out" = "$exp_cat" ] && ck ok "$m (d) concatenated single file agrees with the oracle" || ck no "$m (d) printed [$out], oracle says [$exp_cat]"
done
echo "=== checks=$checks fails=$fails ==="
[ "$fails" -eq 0 ] || { echo "⛔ GATE RED: multi-file prolog drops or reorders a file's directives"; exit 1; }
echo "✅ GATE GREEN: every positional prolog file's directives run, in file order, both modes"
