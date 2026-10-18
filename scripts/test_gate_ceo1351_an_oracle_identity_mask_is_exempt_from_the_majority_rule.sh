#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the x32/x64 runners invoked on one-program scratch fixtures, not a board (CEO-547)"
# test_gate_ceo1351_an_oracle_identity_mask_is_exempt_from_the_majority_rule.sh -- ceo CEO-1344 (2) and CEO-1351 (2026-09-27/28): HOST()
# answers the implementation's own identity ("x86-64:unix :Macro SPITBOL 15.01 #" under sbl -bf), the ORACLE'S OWN INTERNAL STATE, which SCRIP
# does not impersonate -- so spitbol_x32_tests/host.spt and spitbol_x64_tests/host.sbl mask that line and grade on host(0). They print two
# lines, and CEO-409 guardrail 4 read one masked line of two as a majority-masked fixture, UNGRADABLE. CEO-1351 (shape A): a mask row whose
# reason cites CEO-1344 is an ORACLE-IDENTITY row, exempt from the half while at least one line stays unmasked, admitted only as a content
# regex -- one rule, corpus_suite_harness.py's mask_majority(), read by the bash runners through util_apply_ceo409_mask.py's .major; and the
# x32/x64 runners read ALL.mask at all (they did not; the CEO-432 shim was wired into testpgms only).
#
#   S1  shim, a CEO-1344 row masking 1 of 2 oracle lines: count 1, .major 0     S2  the same row with no CEO-1344 in its reason: .major 1
#   S3  a CEO-1344 row matching BOTH lines: .major 1 (nothing left to grade)     S4  a CEO-1344 row plus an ordinary row, one line each: .major 1
#   S5  a CEO-1344 row written L1 refuses rc 2                                    S6  a CEO-1344 row written ORACLE-ONLY refuses rc 2
#   C1  classify(): sbl's two lines against ours "host(): " / "host(0)" with the CEO-1344 row: PASS, 1 masked
#   C2  ours "host(): " / "host(1)": FAIL (the unmasked line still grades)        C3  the row with no CEO-1344 citation: FAIL (guardrail 4)
#   R1  the x32 runner on a one-program fixture (host.spt + the package's own ALL.mask row): PASS both modes, masked_lines=1
#   R2  the same fixture with no ALL.mask: RED both modes                         R3  the x64 runner on host.sbl + its ALL.mask: PASS both modes
# FAIL_ONCE=1 runs S and C against a copy of the harness and shim whose ORACLE_IDENTITY_RULING names no ruling: S1 and C1 red.
# FAIL_ONCE (recorded, hq_snobol4 2026-09-28): on SCRIP c977f18ac (this change stashed, the gate and corpus ALL.mask kept) 9 of 12 red --
#   S1-S4 (the old shim writes no .major), S5 S6 (the old reader admits both rows), C1 (guardrail 4 FAILs host, 1 of 2), R1 R3 (the old
#   runners read no ALL.mask); FAIL_ONCE=1 on the cure reds S1 S5 S6 C1; the cure greens all 12.
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
refuse() { echo "GATE UNPROVEN(2) [$GATE_NAME]: $*"; exit 2; }
PK="${S4E_CORPUS_ROOT:-$ROOT/../corpus}/packages/snobol4"
[ -f "$PK/spitbol_x32_tests/host.spt" ] && [ -f "$PK/spitbol_x64_tests/host.sbl" ] || refuse "host.spt / host.sbl are not in $PK -- the premise moved"
LIB="$HERE"
if [ "${FAIL_ONCE:-}" = 1 ]; then
    mkdir -p "$T/lib"; cp "$HERE/util_apply_ceo409_mask.py" "$T/lib/"
    sed 's/^ORACLE_IDENTITY_RULING = "CEO-1344"$/ORACLE_IDENTITY_RULING = "NO-SUCH-RULING"/' "$HERE/corpus_suite_harness.py" > "$T/lib/corpus_suite_harness.py"
    grep -q '^ORACLE_IDENTITY_RULING = "NO-SUCH-RULING"$' "$T/lib/corpus_suite_harness.py" || refuse "FAIL_ONCE could not neuter ORACLE_IDENTITY_RULING -- the constant moved"
    LIB="$T/lib"; echo "  FAIL_ONCE=1: S and C arms read a harness whose ORACLE_IDENTITY_RULING names no ruling"
fi
SHIM="$LIB/util_apply_ceo409_mask.py"
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  RED  $1 -- $3"; red=$((red+1)); fi; }
ID='CEO-1344 oracle identity: this gate'"'"'s witness line'
ORA=$'host(): x86-64:unix :Macro SPITBOL 15.01 #\nhost(0)\n'
shim() { mkdir -p "$T/$1"; printf '%b' "$2" > "$T/$1/ALL.mask"; printf '%s' "$ORA" | python3 "$SHIM" "$T/$1/ALL.ref" e "$T/$1/n" --side=oracle > "$T/$1/out" 2>"$T/$1/err"; echo $?; }
maj() { cat "$T/$1/n.major" 2>/dev/null || echo missing; }
r="$(shim s1 "e\t^host\\\\(\\\\): .*\$\t$ID\n")"; { [ "$r" = 0 ] && [ "$(cat "$T/s1/n")" = 1 ] && [ "$(maj s1)" = 0 ]; } && arm S1 ok || arm S1 red "rc=$r count=$(cat "$T/s1/n" 2>/dev/null) major=$(maj s1)"
r="$(shim s2 "e\t^host\\\\(\\\\): .*\$\tthe same line with no ruling cited\n")"; { [ "$r" = 0 ] && [ "$(maj s2)" = 1 ]; } && arm S2 ok || arm S2 red "rc=$r major=$(maj s2)"
r="$(shim s3 "e\t^host\t$ID\n")"; { [ "$r" = 0 ] && [ "$(cat "$T/s3/n")" = 2 ] && [ "$(maj s3)" = 1 ]; } && arm S3 ok || arm S3 red "rc=$r count=$(cat "$T/s3/n" 2>/dev/null) major=$(maj s3)"
r="$(shim s4 "e\t^host\\\\(\\\\): .*\$\t$ID\ne\t^host\\\\(0\\\\)\$\tan ordinary row\n")"; { [ "$r" = 0 ] && [ "$(maj s4)" = 1 ]; } && arm S4 ok || arm S4 red "rc=$r major=$(maj s4)"
r="$(shim s5 "e\tL1\t$ID\n")"; [ "$r" = 2 ] && arm S5 ok || arm S5 red "rc=$r, want 2"
r="$(shim s6 "e\tORACLE-ONLY:host(0)\t$ID and CEO-1293\n")"; [ "$r" = 2 ] && arm S6 ok || arm S6 red "rc=$r, want 2"
cv="$(cd "$LIB" && python3 - <<'PY' 2>&1
import importlib.util, re
spec = importlib.util.spec_from_file_location("h", "corpus_suite_harness.py"); h = importlib.util.module_from_spec(spec); spec.loader.exec_module(h)
ora = "host(): x86-64:unix :Macro SPITBOL 15.01 #\nhost(0)\n"
idm = [(("regex", re.compile(r"^host\(\): .*$")), "CEO-1344 oracle identity: gate")]
plain = [(("regex", re.compile(r"^host\(\): .*$")), "no ruling cited")]
for tag, ours, m in (("C1", "host(): \\nhost(0)\\n", idm), ("C2", "host(): \\nhost(1)\\n", idm), ("C3", "host(): \\nhost(0)\\n", plain)):
    v = h.classify(["printf", ours], 10, ora, mask=m)
    print(tag, v.kind, v.masked_lines)
PY
)"
printf '%s\n' "$cv" | grep -qx "C1 PASS 1" && arm C1 ok || arm C1 red "$(printf '%s\n' "$cv" | grep '^C1\|Error' | head -2 | tr '\n' ' ')"
printf '%s\n' "$cv" | grep -q "^C2 FAIL " && arm C2 ok || arm C2 red "$(printf '%s\n' "$cv" | grep '^C2' | tr '\n' ' ')"
printf '%s\n' "$cv" | grep -q "^C3 FAIL " && arm C3 ok || arm C3 red "$(printf '%s\n' "$cv" | grep '^C3' | tr '\n' ' ')"
fld() { printf '%s\n' "$1" | grep -E "^$3 " | tr ' ' '\n' | awk -F= -v k="$2" '$1==k {print $2; exit}'; }
fx() {  # fx <dir> <x32|x64> <with-mask 1|0>
    local d="$T/$1" src ext; if [ "$2" = x32 ]; then src="$PK/spitbol_x32_tests"; ext=spt; else src="$PK/spitbol_x64_tests"; ext=sbl; fi
    mkdir -p "$d"; cp "$src/host.$ext" "$d/"; awk -F, 'NR==1 || $2=="host"' "$src/ALL.csv" > "$d/ALL.csv"
    for f in UNGRADED.tsv EXCLUDED.tsv; do grep '^#' "$src/$f" > "$d/$f"; done; [ "$2" = x64 ] && grep '^#' "$src/NARROW.tsv" > "$d/NARROW.tsv"
    [ "$3" = 1 ] && grep -v '^#' "$src/ALL.mask" | grep '^host	' > "$d/ALL.mask"; return 0; }
[ "$(cd "$T" && timeout -k 5 30 "$O" -bf "$PK/spitbol_x32_tests/host.spt" < /dev/null 2>/dev/null | head -1)" = "host(): x86-64:unix :Macro SPITBOL 15.01 #" ] || refuse "sbl -bf no longer answers HOST() with its identity string -- the premise moved"
runit() { local tag="$1" d="$2"; (cd "$ROOT" && if [ "$tag" = X32 ]; then SPITBOL_X32_SUITE="$T/$d" SPITBOL_X32_SHIPPED=1 TIMEOUT=60 timeout -k 5 300 bash "$HERE/test_snobol4_spitbol_x32_suite.sh"
    else SPITBOL_X64_SUITE="$T/$d" SPITBOL_X64_SHIPPED=1 TIMEOUT=60 timeout -k 5 300 bash "$HERE/test_snobol4_spitbol_x64_suite.sh"; fi 2>&1); }
fx r1 x32 1; [ -s "$T/r1/ALL.mask" ] || refuse "spitbol_x32_tests/ALL.mask carries no host row -- the premise moved"
out="$(runit X32 r1)"; rc=$?
{ [ "$rc" = 0 ] && [ "$(fld "$out" m3_pass SPITBOL_X32_BOARD)" = 1 ] && [ "$(fld "$out" m4_pass SPITBOL_X32_BOARD)" = 1 ] && [ "$(fld "$out" masked_lines SPITBOL_X32_MASKS)" = 1 ]; } \
  && arm R1 ok || arm R1 red "rc=$rc; $(printf '%s\n' "$out" | grep -E '^SPITBOL_X32_(BOARD|MASKS)|REFUSE' | head -3 | cut -c1-140 | tr '\n' ' ')"
fx r2 x32 0; out="$(runit X32 r2)"; rc=$?
{ [ "$rc" = 1 ] && [ "$(fld "$out" m3_fail SPITBOL_X32_BOARD)" = 1 ] && [ "$(fld "$out" m4_fail SPITBOL_X32_BOARD)" = 1 ]; } && arm R2 ok || arm R2 red "rc=$rc; $(printf '%s\n' "$out" | grep -E '^SPITBOL_X32_BOARD' | cut -c1-140)"
fx r3 x64 1; [ -s "$T/r3/ALL.mask" ] || refuse "spitbol_x64_tests/ALL.mask carries no host row -- the premise moved"
out="$(runit X64 r3)"; rc=$?
{ [ "$rc" = 0 ] && [ "$(fld "$out" m3_pass SPITBOL_X64_BOARD)" = 1 ] && [ "$(fld "$out" m4_pass SPITBOL_X64_BOARD)" = 1 ] && [ "$(fld "$out" masked_lines SPITBOL_X64_MASKS)" = 1 ]; } \
  && arm R3 ok || arm R3 red "rc=$rc; $(printf '%s\n' "$out" | grep -E '^SPITBOL_X64_(BOARD|MASKS)|REFUSE' | head -3 | cut -c1-140 | tr '\n' ' ')"
if [ "$red" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: $n arms"; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $red of $n arms red"; exit 1
