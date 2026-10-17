#!/usr/bin/env bash
# test_gate_a_compile_refusal_grades_through_the_one_voice_in_both_modes.sh -- A COMPILE REFUSAL IS A VERDICT, NOT A SKIP (ceo CEO-1354, the
# coo's ask of 2026-09-28 on hq_snobol4's witness packages/snobol4/dotnet/Test2.sno; hq_raku 2026-10-11 on RakRungs class_method_range_replace_6
# and class_method_say_replace_49: "every m4 compile failure is Verdict SKIP, so a program whose correct behaviour IS a compile-time refusal
# can never read PASS in mode 4").
#
# THE DEFECT, MEASURED: on the coo's raku-rungs pass on SCRIP 342a17f55 both entries read PASS in m3 and SKIP in m4 -- their ref is empty,
# their want_rc 1, and scrip --compile exits 1 exactly as Rakudo refuses them -- two of RakRungs' standing non-PASS cells no Raku cure could
# close. compile_m4 returned SKIP for every failed --compile, whatever it meant.
#
# ARMS (a two-entry Raku block suite in mktemp, outside corpus/ (CEO-547), the ALL.wantrc sidecar declaring each entry's rc; nothing recorded):
#   (a) SHARED: hq_raku's witness text (a role's stub method a class leaves unimplemented), ref empty, want_rc 1: PASS in m3 AND in m4
#   (b) UNSHARED: the same refusing text with a ref the oracle "ran" (ok, want_rc 0): FAIL in both modes -- a refusal the oracle does not
#       share is a red, never a skip
#   (c) the board reads m4_skip=0: no refusal of the two is a SKIP
# FAIL_ONCE=1 runs the harness with S4E_M4_COMPILE_REFUSAL_SKIP=1 (the old SKIP), to prove arms (a) and (c) trip.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$HERE/corpus_suite_harness.py"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$H" ] || refuse "no harness at $H"
[ -x "$HERE/../../SCRIP/scrip" ] && [ -f "$HERE/../../SCRIP/out/libscrip_rt.so" ] || refuse "no ./scrip binary or runtime beside ../harness/scripts/ -- make first"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_m4_refusal.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
banner(){ python3 -c 'import sys; t=" %s %s" % (sys.argv[1], sys.argv[2]); print("#" + "-" * (80 - 1 - len(t)) + t)' "$1" "$2"; }
SRC='role R { method needed() {...} }
class C does R { }
 my $c = C.new(); say("made"); '
{ banner 1 refusal_shared; printf '%s\n' "$SRC"; banner 2 refusal_unshared; printf '%s\n' "$SRC"; } > "$W/ALL.raku"
{ banner 1 refusal_shared; banner 2 refusal_unshared; echo ok; } > "$W/ALL.ref"
printf 'refusal_shared\t1\n' > "$W/ALL.wantrc"
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: a compile refusal grades through the one voice in both modes, never a SKIP (CEO-1354) ==="
pre=""; [ -n "${FAIL_ONCE:-}" ] && pre="S4E_M4_COMPILE_REFUSAL_SKIP=1"
out="$(env $pre S4E_PROGRESS_OFF=1 SUITE_LIST_ALL=1 timeout -k 5 300 python3 "$H" run "$W/ALL.raku" "$W/ALL.ref" --lang raku --modes m3,m4 2>&1)"; rc=$?
[ "$rc" -le 1 ] || refuse "the harness could not grade the fixture (rc=$rc): $(tail -3 <<<"$out")"
board="$(grep -m1 '^SUITE_BOARD ' <<<"$out")"; [ -n "$board" ] || refuse "no SUITE_BOARD line: $(tail -3 <<<"$out")"
f(){ grep -oE "(^| )$1=[0-9]+" <<<"$board" | head -1 | sed 's/.*=//'; }
red(){ grep -E "^  [A-Z]+ $1 $2:" <<<"$out" | head -1 | awk '{print $1}'; }
[ "$(f m3_pass)" = 1 ] && [ "$(f m4_pass)" = 1 ] && [ -z "$(red m3 refusal_shared)" ] && [ -z "$(red m4 refusal_shared)" ] \
  && ck ok "(a) the shared refusal (ref empty, want_rc 1) reads PASS in m3 and m4" \
  || ck no "(a) shared refusal: m3_pass=$(f m3_pass) m4_pass=$(f m4_pass), m3 '$(red m3 refusal_shared)' m4 '$(red m4 refusal_shared)'"
[ "$(red m3 refusal_unshared)" = FAIL ] && [ "$(red m4 refusal_unshared)" = FAIL ] \
  && ck ok "(b) the unshared refusal (ref ok, want_rc 0) reads FAIL in both modes" \
  || ck no "(b) unshared refusal: m3 '$(red m3 refusal_unshared)' m4 '$(red m4 refusal_unshared)'"
[ "$(f m4_skip)" = 0 ] && ck ok "(c) m4_skip=0: neither refusal is a SKIP" || ck no "(c) m4_skip=$(f m4_skip)"
echo "population: 2 entries x 2 modes, $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [a_compile_refusal_grades_through_the_one_voice_in_both_modes]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [a_compile_refusal_grades_through_the_one_voice_in_both_modes]: $fails of $checks arms FAIL"; exit 1
