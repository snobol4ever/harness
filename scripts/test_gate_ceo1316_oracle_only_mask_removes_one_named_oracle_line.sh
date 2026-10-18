#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the testpgms runner invoked on a scratch fixture, not a board (CEO-547)"
# test_gate_ceo1316_oracle_only_mask_removes_one_named_oracle_line.sh -- ceo CEO-1316 (2) (2026-09-27, on Lon's "I want to see TPgm go
# to 8/8"): a CEO-409 mask row of the kind ORACLE-ONLY:<exact line> removes ONE line, matched by exact text, from the ORACLE's stream only,
# counted and printed like every mask. It exists for CEO-1293's class -- an enhancement we keep that the oracle lacks (Lon: "Keep the
# VALUE function we like new features"), where the oracle prints a line we never do (testpgms test1's statement-137 trap, error 22).
# CEO-409's replace-never-delete cannot reach a line one side lacks; this kind can, and only that far: our side is never touched, so a
# missing or extra line of ours still reds, and a row whose reason does not cite CEO-1293 is refused.
#
#   S1  shim, --side=oracle: the named line is removed, count 1          S2  --side=scrip: the stream is byte-identical, count 0
#   S3  no side: byte-identical, count 0 (a caller that cannot say whose stream it holds can never delete)
#   S4  a near miss (one trailing blank) is not removed                  S5  of two identical lines, exactly one is removed
#   S6  a reason that does not cite CEO-1293 refuses rc 2
#   C1  the harness's own classify(): oracle "a b c" (b oracle-only) against ours "a c" is PASS, one line masked
#   C2  ours "a b c" (we print the oracle-only line too) is FAIL        C3  ours "a" (a line of ours missing) is FAIL
#   R1  the testpgms runner on a one-program fixture whose SETEXIT handler prints "TRAP 22" only under sbl (it has no VALUE), with the
#       ORACLE-ONLY row beside it: PASS both modes, masked_lines=1
#   R2  the same fixture with no ALL.mask: RED both modes              R3  the row naming "TRAP 23": RED both modes
#   R4  CEO-409's majority guardrail binds this kind too: on a two-line fixture the one removed line is half, and it reds
# FAIL_ONCE (recorded, hq_snobol4 2026-09-27): with corpus_suite_harness.py, util_apply_ceo409_mask.py and the testpgms runner as they
#   stood on SCRIP 8c433e64d (this change stashed), 8 of 13 red -- S1 S2 S4 S5 (the old shim refuses --side), C1 C2 (the old
#   classify never removes the line, so ours "a b c" passed and "a c" failed), R1 R4 (the old runner reads no mask); the cure greens all 13.
# EXIT: 0 every arm passes . 1 an arm is red . 2 REFUSED (no oracle, stale binary, the fixture's premise moved)
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
SHIM="$HERE/util_apply_ceo409_mask.py"; RUNNER="$HERE/test_snobol4_spitbol_testpgms_suite.sh"
refuse() { echo "GATE UNPROVEN(2) [$GATE_NAME]: $*"; exit 2; }
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  RED  $1 -- $3"; red=$((red+1)); fi; }
ROW='ORACLE-ONLY:TRAP 22	CEO-1293 kept enhancement: this gate'"'"'s witness, VALUE, which sbl -bf lacks'

mkdir -p "$T/s"; printf 'e\t%s\n' "$ROW" > "$T/s/ALL.mask"
shim() { local side="$1"; shift; printf "$1" | python3 "$SHIM" "$T/s/ALL.ref" e "$T/s/n" $side; }
o="$(shim --side=oracle 'TRAP 22\ndone\n')"; [ "$o" = done ] && [ "$(cat "$T/s/n")" = 1 ] && arm S1 ok || arm S1 red "got [$o] count $(cat "$T/s/n")"
o="$(shim --side=scrip 'TRAP 22\ndone\n')"; [ "$o" = $'TRAP 22\ndone' ] && [ "$(cat "$T/s/n")" = 0 ] && arm S2 ok || arm S2 red "got [$o] count $(cat "$T/s/n")"
o="$(shim '' 'TRAP 22\ndone\n')"; [ "$o" = $'TRAP 22\ndone' ] && [ "$(cat "$T/s/n")" = 0 ] && arm S3 ok || arm S3 red "got [$o] count $(cat "$T/s/n")"
o="$(shim --side=oracle 'TRAP 22 \ndone\n')"; [ "$o" = $'TRAP 22 \ndone' ] && arm S4 ok || arm S4 red "got [$o]"
o="$(shim --side=oracle 'TRAP 22\nTRAP 22\ndone\n')"; [ "$o" = $'TRAP 22\ndone' ] && [ "$(cat "$T/s/n")" = 1 ] && arm S5 ok || arm S5 red "got [$o] count $(cat "$T/s/n")"
mkdir -p "$T/u"; printf 'e\tORACLE-ONLY:TRAP 22\tno ruling cited\n' > "$T/u/ALL.mask"
printf 'TRAP 22\n' | python3 "$SHIM" "$T/u/ALL.ref" e "$T/u/n" --side=oracle >/dev/null 2>&1; r=$?; [ "$r" = 2 ] && arm S6 ok || arm S6 red "rc=$r, want 2"

cv="$(cd "$HERE" && python3 - <<'PY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("h", "corpus_suite_harness.py"); h = importlib.util.module_from_spec(spec); spec.loader.exec_module(h)
m = [(("oracle_only", "b"), "CEO-1293 kept enhancement: gate")]
for tag, ours in (("C1", "a\\nc\\n"), ("C2", "a\\nb\\nc\\n"), ("C3", "a\\n")):
    v = h.classify(["printf", ours], 10, "a\nb\nc\n", mask=m)
    print(tag, v.kind, v.masked_lines)
PY
)"
printf '%s\n' "$cv" | grep -qx "C1 PASS 1" && arm C1 ok || arm C1 red "$(printf '%s\n' "$cv" | grep '^C1\|Error' | head -2 | tr '\n' ' ')"
printf '%s\n' "$cv" | grep -q "^C2 FAIL " && arm C2 ok || arm C2 red "$(printf '%s\n' "$cv" | grep '^C2' | tr '\n' ' ')"
printf '%s\n' "$cv" | grep -q "^C3 FAIL " && arm C3 ok || arm C3 red "$(printf '%s\n' "$cv" | grep '^C3' | tr '\n' ' ')"

fx() { local tail="\tOUTPUT = 'done'\n\tOUTPUT = 'more 1'\n\tOUTPUT = 'more 2'\t:(END)"; [ "${2:-}" = small ] && tail="\tOUTPUT = 'done'\t:(END)"
      rm -rf "$T/$1"; mkdir -p "$T/$1"; printf "\t&ERRLIMIT = 10\n\tSETEXIT(.ERRORS)\n\tX = 'hi'\n\tY = VALUE('X')\nCONT$tail\nERRORS\tOUTPUT = 'TRAP ' &ERRTYPE\n\tSETEXIT(.ERRORS)\t:(CONT)\nEND\n" > "$T/$1/testval.spt"
      : > "$T/$1/testpgms.in"; printf 'entry,heap_kb,stack_kb,compile_args,run_args\ntestval,131072,4096,,\n' > "$T/$1/ALL.csv"; }
fx r1; [ "$(cd "$T/r1" && timeout -k 5 30 "$O" -bf testval.spt < testpgms.in 2>/dev/null)" = $'TRAP 22\ndone\nmore 1\nmore 2' ] || refuse "sbl -bf no longer prints 'TRAP 22' before its three lines on the fixture -- the premise moved"
[ "$(cd "$T/r1" && timeout -k 5 30 "$ROOT/scrip" testval.spt < testpgms.in 2>/dev/null)" = $'done\nmore 1\nmore 2' ] || refuse "SCRIP no longer prints the three lines alone on the fixture -- the premise moved"
fld() { printf '%s\n' "$1" | grep -E "^$3 " | tr ' ' '\n' | awk -F= -v k="$2" '$1==k {print $2; exit}'; }
runit() { (cd "$ROOT" && SPITBOL_TESTPGMS_SUITE="$T/$1" timeout -k 5 300 bash "$RUNNER" 2>&1); }
printf 'testval\t%s\n' "$ROW" > "$T/r1/ALL.mask"; out="$(runit r1)"; rc=$?
{ [ "$rc" = 0 ] && [ "$(fld "$out" m3_pass SPITBOL_TESTPGMS_BOARD)" = 1 ] && [ "$(fld "$out" m4_pass SPITBOL_TESTPGMS_BOARD)" = 1 ] && [ "$(fld "$out" masked_lines SPITBOL_TESTPGMS_MASKS)" = 1 ]; } \
  && arm R1 ok || arm R1 red "rc=$rc; $(printf '%s\n' "$out" | grep -E '^SPITBOL_TESTPGMS_(BOARD|MASKS)|RED |REFUSE' | head -3 | tr '\n' ' ')"
fx r2; out="$(runit r2)"; rc=$?
{ [ "$rc" = 1 ] && [ "$(fld "$out" m3_fail SPITBOL_TESTPGMS_BOARD)" = 1 ] && [ "$(fld "$out" m4_fail SPITBOL_TESTPGMS_BOARD)" = 1 ]; } && arm R2 ok || arm R2 red "rc=$rc; $(printf '%s\n' "$out" | grep -E '^SPITBOL_TESTPGMS_BOARD' | cut -c1-120)"
fx r3; printf 'testval\tORACLE-ONLY:TRAP 23\tCEO-1293 kept enhancement: the wrong text, which must not match\n' > "$T/r3/ALL.mask"; out="$(runit r3)"; rc=$?
{ [ "$rc" = 1 ] && [ "$(fld "$out" m3_fail SPITBOL_TESTPGMS_BOARD)" = 1 ] && [ "$(fld "$out" m4_fail SPITBOL_TESTPGMS_BOARD)" = 1 ]; } && arm R3 ok || arm R3 red "rc=$rc; $(printf '%s\n' "$out" | grep -E '^SPITBOL_TESTPGMS_BOARD' | cut -c1-120)"

fx r4 small; printf 'testval\t%s\n' "$ROW" > "$T/r4/ALL.mask"; out="$(runit r4)"; rc=$?
{ [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'RED  testval m3 .*majority-masked'; } && arm "R4 (the majority guardrail binds an ORACLE-ONLY row: 1 of 2 lines reds)" ok || arm R4 red "rc=$rc; $(printf '%s\n' "$out" | grep -E 'RED |^SPITBOL_TESTPGMS_BOARD' | head -2 | cut -c1-140 | tr '\n' ' ')"

if [ "$red" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: $n arms"; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $red of $n arms red"; exit 1
